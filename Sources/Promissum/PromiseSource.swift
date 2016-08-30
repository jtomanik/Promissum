//
//  PromiseSource.swift
//  Promissum
//
//  Created by Tom Lokhorst on 2014-10-11.
//  Copyright (c) 2014 Tom Lokhorst. All rights reserved.
//

import Foundation
import Dispatch

/**
 ## Creating Promises

 A PromiseSource is used to create a Promise that can be resolved or rejected.

 Example:

 ```
 let source = PromiseSource<Int, String>()
 let promise = source.promise

 // Register handlers with Promise
 promise
 .then { value in
 print("The value is: \(value)")
 }
 .trap { error in
 print("The error is: \(error)")
 }

 // Resolve the source (will call the Promise handler)
 source.resolve(42)
 ```

 Once a PromiseSource is Resolved or Rejected it cannot be changed anymore.
 All subsequent calls to `resolve` and `reject` are ignored.

 ## When to use
 A PromiseSource is needed when transforming an asynchronous operation into a Promise.

 Example:
 ```
 func someOperationPromise() -> Promise<String, Error> {
 let source = PromiseSource<String, Error>()

 someOperation(callback: { (error, value) in
 if let error = error {
 source.reject(error)
 }
 if let value = value {
 source.resolve(value)
 }
 })

 return promise
 }
 ```

 ## Memory management
 Make sure, when creating a PromiseSource, that someone retains a reference to the source.

 In the example above the `someOperation` retains the callback.
 But in some cases, often when using weak delegates, the callback is not retained.
 In that case, you must manually retain the PromiseSource, or the Promise will never complete.

 Note that `PromiseSource.deinit` by default will log a warning when an unresolved PromiseSource is deallocated.

 */
public class PromiseSource<Value> {
    typealias ResultHandler = (Result<Value, Error>) -> Void

    private var handlers: [(Result<Value, Error>) -> Void] = []
    internal let dispatchMethod: DispatchMethod

    /// The current state of the PromiseSource
    private(set) public var state: State<Value, Error>

    /// Print a warning on deinit of an unresolved PromiseSource
    public var warnUnresolvedDeinit: Bool

    // MARK: Initializers & deinit

    internal convenience init(value: Value) {
        self.init(state: .Resolved(value), dispatch: .Unspecified, warnUnresolvedDeinit: false)
    }

    internal convenience init(error: Error) {
        self.init(state: .Rejected(error), dispatch: .Unspecified, warnUnresolvedDeinit: false)
    }

    /// Initialize a new Unresolved PromiseSource
    ///
    /// - parameter warnUnresolvedDeinit: Print a warning on deinit of an unresolved PromiseSource
    public convenience init(dispatch: DispatchMethod = .Unspecified, warnUnresolvedDeinit: Bool = true) {
        self.init(state: .Unresolved, dispatch: dispatch, warnUnresolvedDeinit: warnUnresolvedDeinit)
    }

    internal init(state: State<Value, Error>, dispatch: DispatchMethod, warnUnresolvedDeinit: Bool) {
        self.state = state
        self.dispatchMethod = dispatch
        self.warnUnresolvedDeinit = warnUnresolvedDeinit
    }

    deinit {
        if warnUnresolvedDeinit {
            switch state {
            case .Unresolved:
                print("PromiseSource.deinit: WARNING: Unresolved PromiseSource deallocated, maybe retain this object?")
            default:
                break
            }
        }
    }


    // MARK: Computed properties

    /// Promise related to this PromiseSource
    public var promise: Promise<Value> {
        return Promise(source: self)
    }


    // MARK: Resolve / reject

    /// Resolve an Unresolved PromiseSource with supplied value.
    ///
    /// When called on a PromiseSource that is already Resolved or Rejected, the call is ignored.
    public func resolve(value: Value) {

        resolveResult(result: .Value(value))
    }


    /// Reject an Unresolved PromiseSource with supplied error.
    ///
    /// When called on a PromiseSource that is already Resolved or Rejected, the call is ignored.
    public func reject(error: Error) {

        resolveResult(result: .Error(error))
    }

    internal func resolveResult(result: Result<Value, Error>) {

        switch state {
        case .Unresolved:
            state = result.state

            executeResultHandlers(result: result)
        default:
            break
        }
    }

    private func executeResultHandlers(result: Result<Value, Error>) {

        // Call all previously scheduled handlers
        callHandlers(value: result, handlers: handlers, dispatchMethod: dispatchMethod)

        // Cleanup
        handlers = []
    }

    // MARK: Adding result handlers

    internal func addOrCallResultHandler(handler: @escaping (Result<Value, Error>) -> Void) {

        switch state {
        case .Unresolved:
            // Save handler for later
            handlers.append(handler)

        case .Resolved(let value):
            // Value is already available, call handler immediately
            callHandlers(value: Result.Value(value), handlers: [handler], dispatchMethod: dispatchMethod)

        case .Rejected(let error):
            // Error is already available, call handler immediately
            callHandlers(value: Result.Error(error), handlers: [handler], dispatchMethod: dispatchMethod)
        }
    }
}

internal func callHandlers<T>(value: T, handlers: [(T) -> Void], dispatchMethod: DispatchMethod) {

    for handler in handlers {
        switch dispatchMethod {
        case .Unspecified:
            #if os(Linux)
                DispatchQueue.main.async {
                    handler(value)
                }
            #else
                if Thread.isMainThread {
                    handler(value)
                }
                else {
                    DispatchQueue.main.async {
                        handler(value)
                    }
                }
            #endif
            
        case .Synchronous:
            handler(value)
            
        case let .OnQueue(targetQueue):
            targetQueue.async {
                handler(value)
            }
        }
    }
}

