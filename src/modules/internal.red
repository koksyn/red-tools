Red [
    Package: "RedUnit"
    Title: "Internal"
    Description: "Internal methods and fields for RedUnit tool."
    Purpose: "Encapsulating internal source of RedUnit."
    Author: "Mateusz Palichleb"
    File: %internal.red
]

context [
    /local errors: make map![]
    /local tests: copy []
    /local setup-detected: false
    /local error-expected: false
    /local actual-test-name: copy ""
    /local buffer: do %../utils/string-buffer.red
    /local execution-time: 0.0
    /local prefix: copy ""
    /local postfix: copy "-tests"

    /local run-dir: func [
        "Will detect and execute all '<prefix>***<postfix>.red' test objects under '<dir>' directory"
        dir[file!]
    ] [
        files: read dir

        foreach file files [
            path: rejoin [dir file]

            case [
                valid-filename file [
                    run-file path
                ]
                dir? file [ ;-- recursion on subdirectory
                    run-dir path
                ]
            ]
        ]
    ]

    /local run-file: func [
        "Run all tests from provided object (loaded from filepath), which should consist at least one test method"
        filepath[file!]
    ] [
        buffer/put rejoin [ "^/[FILE] " filepath "^/"]

        file-dir: pick (split-path filepath) 1

        ; load testable file
        boot-dir: what-dir
        code: read filepath
        change-dir file-dir
        testable: do code

        run-object testable
        
        ; revert boot directory
        change-dir boot-dir
    ]

    /local run-object: func [
        testable[object!]
    ] [
        process-testable-methods testable
        
        started: now/time/precise/utc

        foreach test tests [
            if setup-detected [do testable/setup]
            execute-test test
        ]

        ended: now/time/precise/utc

        add-execution-time started ended
    ]

    /local process-testable-methods: func [
        "Will detect 'setup' and 'test***' methods - and prepare them to execution"
        testable[object!]
    ] [
        setup-detected: false
        tests: copy []

        methods: words-of testable  

        foreach method methods [
            method-name: to string! method

            case [
                method-name = "setup" [
                    setup-detected: true
                ]
                find/case method-name "test" [
                    insert tail tests method
                ]
            ]
        ]

        if (length? tests) = 0 [
            print "[Error] Provided object does not have any test method!"
            halt
        ]
    ]

    /local execute-test: func [
        "Executes one test method"
        test
    ] [
        buffer/put rejoin ["[test] " test " "]

        ; reset context of expected error for each test
        error-expected: false
        result: none
        ; define actually executed test name
        actual-test-name: to string! test

        errors-before: length? errors

        was-error: none? attempt [ 
            result: try [do test] 
        ]

        unless none? result [
            case [
                was-error and (not error-expected) [
                    put errors test result
                ]
                (not was-error) and error-expected [
                    message: "Expected error, but nothing happen."
                    fail-test message "error-expected"
                ]
            ]
        ]

        errors-after: length? errors

        either errors-before <> errors-after [
            buffer/putline "[Failure]"
        ] [
            buffer/putline "[Success]"
        ]
    ]

    /local add-execution-time: func [
        "Adds new execution time to existing time"
        started[time!] ended[time!]
    ] [
        interval: to float! ended - started

        execution-time: execution-time + interval
    ]

    ; Print interval of execution time (in seconds) in Console
    /local attach-execution-time: does [
        ms: execution-time * 1000
        buffer/put rejoin ["^/Time: " ms " ms"] 
    ]

    ;-- Print all catched errors in Console
    /local attach-catched-errors: does [
        were-errors: (length? errors) > 0

        if were-errors [
            buffer/putline "^/---- Errors ----^/"

            keys: reflect errors 'words
            foreach key keys [
                buffer/putline rejoin [key ":^/" select errors key "^/"]
            ]
        ]
    ]

    ;-- Returns EXIT CODE 1 - when there were some failed tests 
    /local quit-when-errors: does [
        if (length? errors) > 0 [
            quit-return 1
        ]
    ]

    /local fail-test: func [
        "Cause actual test failure - internally from assertions"
        message[string!] assertion[string!]
    ] [
        issue: make error! [
            code: none
            type: 'user
            id: 'message
            arg1: message
            where: append "assert-" assertion
        ]

        issue-number: (length? errors) + 1
        issue-key: rejoin [actual-test-name "-" assertion "-" issue-number]

        put errors issue-key issue
    ]

    ; clears the whole context (can be used to re-run tests)
    /local clear-context: does [
        buffer/clear
        errors: make map![]
        tests: copy []
        setup-detected: false
        error-expected: false
        actual-test-name: copy ""
        execution-time: 0.0
    ]

    /local require-path-exist: func [
        path[file!]
    ] [
        unless exists? path [
            cause-error 'user 'message [
                arg1: rejoin [
                    "Provided path '" path "' does not exist! "
                    "File or directory not found."
                ]
            ]
        ]
    ]

    /local valid-filename: func [
        "Checks that filename match a pattern '<prefix>***<postfix>.red'"
        file[file!]
    ] [
        suffix: suffix? file

        if suffix <> ".red" [
            return false
        ]

        filename-length: (length? file) - (length? suffix)
        filename: to string! (copy/part file filename-length)

        pre-length: length? prefix
        post-length: length? postfix
        
        if filename-length < (pre-length + post-length) [
            return false
        ]

        filename-head: copy/part filename pre-length
        filename-tail: at tail filename (-1 * post-length)

        return (filename-head == prefix) and (filename-tail == postfix)
    ]
]