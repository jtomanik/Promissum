//
//  PromiseSource+Throw.swift
//  Promissum
//
//  Created by Jakub Tomanik on 18/07/16.
//
//

import Foundation

public extension Promise where Error : ErrorProtocol {

  /// Returns a Promise where the error is casted to an ErrorProtocol.
  @warn_unused_result(message: "Forget to call `then` or `trap`?")
  public func mapErrorProtocol() -> Promise<Value, ErrorProtocol> {
    return self.mapError { $0 }
  }

  /// Return a Promise containing the results of mapping `transform` over the value of `self`.
  @warn_unused_result(message: "Forget to call `then` or `trap`?")
  public func map<NewValue>(transform: (Value) throws -> NewValue) -> Promise<NewValue, Error> {
    let resultSource = PromiseSource<NewValue, Error>(state: .Unresolved, dispatch: self.source.dispatchMethod, warnUnresolvedDeinit: true)

    let handler: (Result<Value, Error>) -> Void = { result in
      switch result {
      case .Value(let value):
        do {
          let transformed = try transform(value)
          resultSource.resolve(value: transformed)
        } catch let error as Error {
          resultSource.reject(error: error)
        } catch {
            fatalError("uncaught error")
        }
       case .Error(let error):
         resultSource.reject(error: error)
       }
    }
        
        source.addOrCallResultHandler(handler: handler)
        
        return resultSource.promise
    }
}