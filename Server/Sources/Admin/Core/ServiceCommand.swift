//
//  ServiceCommand.swift
//  
//
//  Created by Yuu Zheng on 2/27/23.
//

import Foundation
import SwiftyScript

protocol ServiceCommandDelegate: AnyObject {
    var services: [Service] { get }
    func reloadServices() async throws
}

class ServiceCommand {

    weak var delegate: ServiceCommandDelegate?

    let scriptsPath = workspace + "../../Server/Scripts/"

    let queue = DispatchQueue(label: "ServiceCommand", attributes: .concurrent)

    lazy var methods: [String: (String) -> String] = [
        "update": buildNoArgMethodHandle(name: "update", handle: update),
        "build": buildNoArgMethodHandle(name: "build", handle: build),
        "clean": buildNoArgMethodHandle(name: "clean", handle: clean),
        "run": buildOneArgMethodHandle(name: "run", noArgHandle: runAllTask, handle: runTask),
        "kill": buildOneArgMethodHandle(name: "kill", noArgHandle: killAllTask, handle: killTask),
        "reboot": buildOneArgMethodHandle(name: "reboot", noArgHandle: rebootAllTask, handle: rebootTask),
        "status": buildOneArgMethodHandle(name: "status", noArgHandle: allTaskStatus, handle: taskStatus),
        "clear": buildNoArgMethodHandle(name: "clear", handle: clearScreen),
        "exit": { _ in
            print(self.killAllTask())
            print("> exit: Exit in 3 sec...".magenta)
            Thread.sleep(forTimeInterval: 1)
            print("> exit: Exit in 2 sec...".magenta)
            Thread.sleep(forTimeInterval: 1)
            print("> exit: Exit in 1 sec...".magenta)
            Thread.sleep(forTimeInterval: 1)
            print("> exit: Bye!".magenta)
            exit(0)
        },
        "help": { _ in
            return
                """
                ========
                >> \("update".cyan)
                >> \("build".cyan)
                >> \("clean".cyan)
                >> \("run".cyan) [task]
                >> \("kill".cyan) [task]
                >> \("reboot".cyan) [task]
                >> \("clear".cyan)
                >> \("exit".cyan)
                ========
                """
        }
    ]

    func runCommand(_ command: String) -> String? {
        let cmds = command.components(separatedBy: " & ")
        for cmd in cmds {
            guard cmd.count > 0 else {
                continue
            }
            guard let method = cmd.components(separatedBy: " ").first else {
                continue
            }
            guard let handler = methods[method] else {
                return "> Cannot find method `\(method)` !".onRed
            }
            return handler(cmd)
        }
        return nil
    }

    // MARK: - Command

    func build() -> String {
        let command = "cd '\(scriptsPath)' && ./build.sh"
        return runTask(name: "build", command: command)
    }

    func clean() -> String {
        let command = "cd '\(scriptsPath)' && ./clean.sh"
        return runTask(name: "clean", command: command)
    }

    func update() -> String {
        let command = "cd '\(scriptsPath)' && ./update.sh"
        return runTask(name: "update", command: command)
    }

    func runTask(name: String) -> String {
        guard let task = service(for: name)?.task else {
            return "> run: Cannot found task named [\(name)]!".red
        }
        guard !task.isRunning else {
            return "> run: Task [\(name)] is already running!".red
        }
        queue.async {
            _ = task.run()
        }
        return "> run: Booted!".onMagenta
    }

    func runAllTask() -> String {
        ServiceManager.shared.services.forEach {
            _ = runTask(name: $0.name)
            Thread.sleep(forTimeInterval: 1)
        }
        return "> run: Done!".onMagenta
    }

    func taskStatus(name: String) -> String {
        guard let task = service(for: name)?.task else {
            return "> status: Cannot found task named [\(name)]!".red
        }
        if task.isRunning {
            guard let pid = task.pid, let dateStr = task.startDate else {
                return "> status: Task [\(name)] maybe is already dead.".red
            }
            let date = Utils.dateFormatter.string(from: dateStr)
            return "> status: Task [\(name)] is running at \(pid) since \(date).".green
        } else {
            return "> status: Task [\(name)] is not running.".red
        }
    }

    func allTaskStatus() -> String {
        var log = [String]()
        delegate?.services.forEach {
            log.append(taskStatus(name: $0.name))
        }
        return log.joined(separator: "\n")
    }

    func killTask(name: String) -> String {
        guard let task = service(for: name)?.task else {
            return "> kill: Cannot found task named [\(name)]!".red
        }
        guard task.isRunning else {
            return "> kill: Task [\(name)] is not running!".red
        }
        guard let pid = task.pid else {
            return "> kill: Task [\(name)] maybe is already dead!".red
        }
        buildTask(name: "kill", command: "pkill -9 -P \(pid)").fastRun()
        return "> kill: killed!".onMagenta
    }

    func killAllTask() -> String {
        delegate?.services.forEach {
            _ = killTask(name: $0.name)
        }
        return "> kill: Done!".onMagenta
    }

    func rebootTask(name: String) -> String {
        guard service(for: name) != nil else {
            return "> reboot: Cannot found task named [\(name)]!".red
        }
        var log = [String]()
        log.append(killTask(name: name))
        Thread.sleep(forTimeInterval: 1)
        log.append(runTask(name: name))
        return log.joined(separator: "\n")
    }

    func rebootAllTask() -> String {
        return [
            killAllTask(),
            runAllTask()
        ].joined(separator: "\n")
    }

    func clearScreen() -> String {
        let task = Task(
            language: .Bash,
            output: .console,
            name: "Clear Screen",
            workspace: "/tmp/",
            content: "clear",
            printTaskInfo: false
        )
        guard let termPtr = getenv("TERM"), let term = String.init(utf8String: termPtr) else {
            return "> clear: TERM is nil!".red
        }
        task.environment["TERM"] = term
        task.fastRun()
        return "> clear: Done!".onMagenta
    }

    // MARK: - Utils

    func buildTask(name: String, command: String) -> Task {
        let taskId = UUID().uuidString
        let scriptsPath = workspace + "Scripts/"
        return Task(
            language: .Bash,
            output: .console,
            name: "\(name)_\(taskId)",
            workspace: scriptsPath,
            content: command
        )
    }

    private func service(for name: String) -> Service? {
        return delegate?.services.first(where: { $0.name == name })
    }

    private func runTask(name: String, command: String) -> String {
        let result = buildTask(name: name, command: command).fastRun()
        switch result {
        case .success:
            return "Success"
        case .error(let error):
            return "Error: " + String(describing: error)
        case .failed(let code):
            return "Failed with code: \(code)"
        }
    }

    private func buildNoArgMethodHandle(name: String, handle: @escaping () -> String) -> (String) -> String {
        return { cmd in
            let args = cmd.components(separatedBy: " ")
            if args.count == 1 {
                return handle()
            } else {
                return "> \(name): Too many args!"
            }
        }
    }

    private func buildOneArgMethodHandle(name: String, noArgHandle: @escaping () -> String, handle: @escaping (String) -> String) -> (String) -> String {
        return { cmd in
            let args = cmd.components(separatedBy: " ")
            if args.count == 1 {
                return noArgHandle()
            } else if args.count == 2 {
                return handle(args[1])
            } else {
                return "> \(name): Too many args !"
            }
        }
    }

}
