//
//  TestGenerator.swift
//  AcceptanceMark
//
//  Created by Andrea Bizzotto on 12/08/2016.
//  Copyright © 2016 musevisions. All rights reserved.
//

import Cocoa

enum Language: String {
    case swift3
    case swift2
    
    init(value: String) {
        let lowercaseValue = value.lowercased()
        if lowercaseValue.contains("swift2") {
            self = .swift2
        }
        else if lowercaseValue.contains("swift3") {
            self = .swift3
        }
        else {
            print("Failed detecting language: \(value). Defaulting to Swift 3")
            self = .swift3
        }
    }
}

class TestGenerator: NSObject {

    class func generateTests(testSpecs: [TestSpec], outputDir: String, language: Language) {
        
        for testSpec in testSpecs {
            let source = generateTestsSource(testSpec: testSpec, language: language)
            let path = "\(outputDir)/\(testSpec.sourceFileName)"
            do {
                try (source as NSString).write(toFile: path, atomically: true, encoding: String.Encoding.utf8.rawValue)
                print("Exported \(language.rawValue) code: \(path)")
            }
            catch {
                print("Failed writing file: \(path)")
            }
        }
    }
    
    class func generateTestsSource(testSpec: TestSpec, language: Language) -> String {
        
        // Header
        var source: String = ""
        source.append(
            "/*\n" +
            " * File Auto-Generated by AcceptanceMark - DO NOT EDIT\n" +
            " * input file: \(testSpec.fileName)\n" +
            " * generated file: \(testSpec.sourceFileName)\n" +
            " *\n" +
            " * -- Test Specification -- \n" +
            " *\n")
        
        for line in testSpec.testLines {
            source.append(" * \(line)\n")
        }
        
        source.append(" */\n") // TODO: Add input test.md

        // Imports
        source.append(
            "import XCTest\n" +
            "\n")
        
        // Input struct
        var testInputs: String = ""
        for inputVar in testSpec.inputVars {
            testInputs.append("\tlet \(inputVar.name): \(inputVar.type.rawValue)\n")
        }
        
        let testClassIdentifier = "\(testSpec.namespace)_\(testSpec.testName)"
        let inputStructName = "\(testClassIdentifier)Input"
        source.append(
            "struct \(inputStructName) {\n" +
            testInputs +
            "}\n\n")
        
        // Output struct
        var testOutputs: String = ""
        for outputVar in testSpec.outputVars {
            testOutputs.append("\tlet \(outputVar.name): \(outputVar.type.rawValue)\n")
        }
        
        let outputStructName = "\(testClassIdentifier)Output"
        source.append(
            "struct \(outputStructName): Equatable {\n" +
                testOutputs +
            "}\n\n")

        // Runnable protocol
        source.append(
            "protocol \(testClassIdentifier)Runnable {\n" +
            "\tfunc run(input: \(inputStructName)) throws -> \(outputStructName)\n" +
            "}\n")

        // All tests
        var tests: String = ""
        var testIndex = 0
        for test in testSpec.tests {
            let inputParametersList = testSpec.inputParametersList(for: test)
            let outputParametersList = testSpec.outputParametersList(for: test)
            
            let testRunnerInputParameter = language == .swift3 ? "input: ": ""
            tests.append(
                "\tfunc test\(testSpec.testName)_\(testIndex)() {\n" +
                "\t\tlet input = \(inputStructName)(\(inputParametersList))\n" +
                "\t\tlet expected = \(outputStructName)(\(outputParametersList))\n" +
                "\t\tlet result = try! testRunner.run(\(testRunnerInputParameter)input)\n" +
                "\t\tXCTAssertEqual(expected, result)\n" +
                "\t}\n\n"
            )
            testIndex += 1
        }
        
        // XCTestCase class
        source.append(
            "class \(testClassIdentifier)Tests: XCTestCase {\n" +
            "\n" +
            "\tvar testRunner: \(testClassIdentifier)Runnable!\n" +
            "\n" +
            "\toverride func setUp() {\n" +
            "\t\t// MARK: Implement the \(testClassIdentifier)TestRunner() class!\n" +
            "\t\ttestRunner = \(testClassIdentifier)Runner()\n" +
            "\t}\n" +
            "\n" +
            tests +
            "}\n\n"
        )

        let equalityChecks = testSpec.outputVars.map { "\t\tlhs.\($0.name) == rhs.\($0.name)" }
        let equalityChecksString = equalityChecks.joined(separator: " &&\n")
        source.append(
            "func == (lhs: \(outputStructName), rhs: \(outputStructName)) -> Bool {\n" +
            "\treturn\n" +
            "\(equalityChecksString)\n" +
            "}\n"
        )
        
        // Append sample runner code
        source.append(
            "//\n" +
            "//// You need to create a test runner. Sample runner: \n" +
            "//class \(testClassIdentifier)Runner : \(testClassIdentifier)Runnable {\n" +
            "//\n" +
            "//\tfunc run(input: \(inputStructName)) throws -> \(outputStructName) {\n" +
            "//\t\t//return <\(outputStructName)>\n" +
            "//\t}\n" +
            "//}\n" +
            "//"
        )
        
        return source
    }
}
