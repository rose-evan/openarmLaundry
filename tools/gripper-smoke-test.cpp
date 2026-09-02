// Copyright 2026
// SPDX-License-Identifier: Apache-2.0

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <csignal>
#include <cstdlib>
#include <exception>
#include <iostream>
#include <string>
#include <thread>

#include <openarm/can/socket/openarm.hpp>
#include <openarm/damiao_motor/dm_motor_constants.hpp>
#include <openarm/damiao_motor/dm_motor_control.hpp>

namespace {

std::atomic_bool stop_requested{false};

void request_stop(int) { stop_requested.store(true); }

class TorqueOffGuard {
public:
    explicit TorqueOffGuard(openarm::can::socket::OpenArm& arm) : arm_(arm) {}

    ~TorqueOffGuard() {
        if (!armed_) return;
        try {
            arm_.disable_all();
            arm_.recv_all(100000);
        } catch (...) {
            std::cerr << "WARNING: automatic torque-off command failed\n";
        }
    }

    void arm() { armed_ = true; }
    void disarm() { armed_ = false; }

private:
    openarm::can::socket::OpenArm& arm_;
    bool armed_ = false;
};

double smoothstep(double x) { return x * x * (3.0 - 2.0 * x); }

void command_for(openarm::can::socket::OpenArm& arm, double start, double target,
                 std::chrono::milliseconds move_duration, double& min_position,
                 double& max_position) {
    using namespace std::chrono;
    constexpr auto period = milliseconds(10);
    const auto began = steady_clock::now();

    while (!stop_requested.load()) {
        const auto elapsed = steady_clock::now() - began;
        const double fraction = std::min(
            1.0, duration_cast<std::chrono::duration<double>>(elapsed).count() /
                     duration_cast<std::chrono::duration<double>>(move_duration).count());
        const double commanded = start + (target - start) * smoothstep(fraction);

        // Low gains deliberately cap the force of this detection-only jog.
        arm.get_gripper().mit_control_one(
            0, openarm::damiao_motor::MITParam{3.0, 0.25, commanded, 0.0, 0.0});
        arm.recv_all(2000);

        const double measured = arm.get_gripper().get_motor()->get_position();
        if (std::isfinite(measured)) {
            min_position = std::min(min_position, measured);
            max_position = std::max(max_position, measured);
        }

        if (fraction >= 1.0) break;
        std::this_thread::sleep_for(period);
    }
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 2 || argc > 3) {
        std::cerr << "Usage: " << argv[0] << " CAN_INTERFACE [DELTA_RADIANS]\n";
        return 2;
    }

    const std::string interface = argv[1];
    const double delta = argc == 3 ? std::strtod(argv[2], nullptr) : 0.08;
    if (!std::isfinite(delta) || std::abs(delta) > 0.15 || std::abs(delta) < 0.01) {
        std::cerr << "Delta must be between 0.01 and 0.15 radians in magnitude\n";
        return 2;
    }

    std::signal(SIGINT, request_stop);
    std::signal(SIGTERM, request_stop);

    try {
        using openarm::damiao_motor::CallbackMode;
        using openarm::damiao_motor::ControlMode;
        using openarm::damiao_motor::MITParam;
        using openarm::damiao_motor::MotorType;

        openarm::can::socket::OpenArm arm(interface, true);
        arm.init_gripper_motor(MotorType::DM4310, 0x08, 0x18, ControlMode::MIT);
        TorqueOffGuard torque_off(arm);

        // Drain the control-mode parameter response generated during initialization,
        // then obtain position through the motor's parameter channel. A pending
        // parameter frame must never be interpreted as state telemetry.
        arm.recv_all(100000);
        arm.set_callback_mode_all(CallbackMode::PARAM);
        arm.query_param_all(static_cast<int>(openarm::damiao_motor::RID::p_m));
        arm.recv_all(100000);

        const double start = arm.get_gripper().get_motor()->get_param(
            static_cast<int>(openarm::damiao_motor::RID::p_m));
        if (!std::isfinite(start)) {
            std::cerr << "No valid state response from gripper motor 0x08\n";
            return 1;
        }
        std::cout << "Starting position: " << start << " rad\n";
        if (std::abs(start + delta) > 12.0) {
            std::cerr << "Jog target would be too close to the motor position limit\n";
            return 1;
        }

        std::cout << "Target position:   " << start + delta << " rad\n";

        // Prime a zero-force command before enabling, then begin the bounded jog.
        arm.set_callback_mode_all(CallbackMode::STATE);
        arm.get_gripper().mit_control_one(0, MITParam{0.0, 0.0, start, 0.0, 0.0});
        arm.recv_all(2000);
        arm.enable_all();
        torque_off.arm();
        arm.recv_all(100000);

        double min_position = start;
        double max_position = start;
        command_for(arm, start, start + delta, std::chrono::milliseconds(700), min_position,
                    max_position);
        if (!stop_requested.load()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(250));
            command_for(arm, start + delta, start, std::chrono::milliseconds(700), min_position,
                        max_position);
        }

        arm.disable_all();
        arm.recv_all(100000);
        torque_off.disarm();

        const double final_position = arm.get_gripper().get_motor()->get_position();
        std::cout << "Observed range:    " << min_position << " to " << max_position << " rad\n";
        std::cout << "Final position:    " << final_position << " rad\n";
        std::cout << "Torque disabled\n";
        return stop_requested.load() ? 130 : 0;
    } catch (const std::exception& error) {
        std::cerr << "Smoke test failed: " << error.what() << '\n';
        return 1;
    }
}
