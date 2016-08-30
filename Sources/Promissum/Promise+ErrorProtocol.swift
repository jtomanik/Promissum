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
  
    public func map<NewValue>(transform: @escaping (Value) throws -> NewValue) -> Promise<NewValue> {
        let resultSource = PromiseSource<NewValue>(state: .Unresolved, dispatch: self.source.dispatchMethod, warnUnresolvedDeinit: true)

        let handler: (Result<Value, Error>) -> Void = { result in
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
  
    public func mapError(transform: @escaping (Error) throws -> Value) -> Promise<Value> {
        let resultSource = PromiseSource<Value>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

        let handler: (Result<Value, Error>) -> Void = { result in
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
  
    public func flatMapError(transform: @escaping (Error) throws -> Promise<Value>) -> Promise<Value> {
        let resultSource = PromiseSource<Value>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

        let handler: (Result<Value, Error>) -> Void = { result in
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
