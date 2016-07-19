//
//  PromiseSource+Throw.swift
//  Promissum
//
//  Created by Jakub Tomanik on 18/07/16.
//
//

import Foundation

public extension Promise {

    /// Return a Promise containing the results of mapping throwable `transform` over the value of `self`.
    @warn_unused_result(message: "Forget to call `then` or `trap`?")
    public func map<NewValue>(transform: (Value) throws -> NewValue) -> Promise<NewValue> {
        let resultSource = PromiseSource<NewValue>(state: .Unresolved, dispatch: self.source.dispatchMethod, warnUnresolvedDeinit: true)

        let handler: (Result<Value, ErrorProtocol>) -> Void = { result in
            switch result {
            case .Value(let value):
                do {
                    let transformed = try transform(value)
                    resultSource.resolve(value: transformed)
                } catch {
                    resultSource.reject(error: error)
                }
            case .Error(let error):
                resultSource.reject(error: error)
            }
        }

        source.addOrCallResultHandler(handler: handler)

        return resultSource.promise
    }

    /// Return a Promise containing the results of mapping `transform` over the error of `self`.
    @warn_unused_result(message: "Forget to call `then` or `trap`?")
    public func mapError(transform: (ErrorProtocol) throws -> Value) -> Promise<Value> {
        let resultSource = PromiseSource<Value>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

        let handler: (Result<Value, ErrorProtocol>) -> Void = { result in
            switch result {
            case .Value(let value):
                resultSource.resolve(value: value)
            case .Error(let error):
                do {
                    let newValue = try transform(error)
                    resultSource.resolve(value: newValue)
                } catch {
                    resultSource.reject(error: error)
                }
            }
        }

        source.addOrCallResultHandler(handler: handler)

        return resultSource.promise
    }

    /// Returns the flattened result of mapping `transform` over the error of `self`.
    @warn_unused_result(message: "Forget to call `then` or `trap`?")
    public func flatMapError(transform: (ErrorProtocol) throws -> Promise<Value>) -> Promise<Value> {
        let resultSource = PromiseSource<Value>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

        let handler: (Result<Value, ErrorProtocol>) -> Void = { result in
            switch result {
            case .Value(let value):
                resultSource.resolve(value: value)
            case .Error(let error):
                do {
                    let newPromise = try transform(error)
                    newPromise
                        .then(handler: resultSource.resolve)
                        .trap(handler: resultSource.reject)
                } catch {
                    resultSource.reject(error: error)
                }
            }
        }
        
        source.addOrCallResultHandler(handler: handler)
        
        return resultSource.promise
    }
}