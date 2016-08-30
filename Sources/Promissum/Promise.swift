//
//  Promise.swift
//  Promissum
//
//  Created by Tom Lokhorst on 2014-10-11.
//  Copyright (c) 2014 Tom Lokhorst. All rights reserved.
//

import Foundation
import Dispatch

/**
## A future value

_A Promise represents a future value._

To access it's value, register a handler using the `then` method:

```
somePromise.then { value in
  print("The value is: \(value)")
}
```

You can register multiple handlers to access the value multiple times.
To register more multiple handlers, simply call `then` multiple times.
Once available, the value becomes immutable and will never change.

## Failure

A Promise can fail during the computation of the future value.
In that case the error can also be accessed by registering a handler with `trap`:

```
somePromise.trap { error in
  print("The error is: \(error)")
}
```


## States

A Promise is always in one of three states: Unresolved, Resolved, or Rejected.
Once a Promise changes from Unresolved to Resolved/Rejected the appropriate registered handlers are called.
After the Promise has changed from Unresolved, it will always stay either Resolved or Rejected.

It is possible to register for both the value and the error, like so:

```
somePromise
  .then { value in
    print("The value is: \(value)")
  }
  .trap { error in
    print("The error is: \(error)")
  }
```


## Types

The full type `Promise<Value, Error>` has two type arguments, for both the value and the error.

For example; the type `Promise<String, NSError>` represents a future value of type `String` that can potentially fail with a `NSError`.
When creating a Promise yourself, it is recommended to use a custom enum to represent the possible errors cases.

In cases where an error is not applicable, you can use the `NoError` type.


## Transforming a Promise value

Similar to `Array`, a Promise has a `map` method to apply a transform the value of a Promise.

In this example an age (Promise of int) is transformed to a future isAdult boolean:

```
// agePromise has type Promise<Int, NoError>
// isAdultPromise has type Promise<Bool, NoError>
let isAdultPromise = agePromise.map { age in age >= 18 }

```

Again, similar to Arrays, `flatMap` is also available.


## Creating a Promise

To create a Promise, use a `PromiseSoure`.
Note that it is often not needed to create a new Promise.
If an existing Promise is available, transforming that using `map` or `flatMap` is often sufficient.

*/
public struct Promise<Value> {
  internal let source: PromiseSource<Value>


  // MARK: Initializers

  /// Initialize a resolved Promise with a value.
  ///
  /// Example: `Promise<Int, NoError>(value: 42)`
  public init(value: Value) {
    self.source = PromiseSource(value: value)
  }

  /// Initialize a rejected Promise with an error.
  ///
  /// Example: `Promise<Int, String>(error: "Oops")`
  public init(error: Error) {
    self.source = PromiseSource(error: error)
  }

  internal init(source: PromiseSource<Value>) {
    self.source = source
  }


  // MARK: Computed properties

  /// Optionally get the underlying value of this Promise.
  /// Will be `nil` if Promise is Rejected or still Unresolved.
  ///
  /// In most situations it is recommended to register a handler with `then` method instead of directly using this property.
  public var value: Value? {
    switch source.state {
    case .Resolved(let value):
      return value
    default:
      return nil
    }
  }

  /// Optionally get the underlying error of this Promise.
  /// Will be `nil` if Promise is Resolved or still Unresolved.
  ///
  /// In most situations it is recommended to register a handler with `trap` method instead of directly using this property.
  public var error: Error? {
    switch source.state {
    case .Rejected(let error):
      return error
    default:
      return nil
    }
  }

  /// Optionally get the underlying result of this Promise.
  /// Will be `nil` if Promise still Unresolved.
  ///
  /// In most situations it is recommended to register a handler with `finallyResult` method instead of directly using this property.
  public var result: Result<Value, Error>? {
    switch source.state {
    case .Resolved(let boxed):
      return .Value(boxed)
    case .Rejected(let boxed):
      return .Error(boxed)
    default:
      return nil
    }
  }


  // MARK: - Attach handlers

  /// Register a handler to be called when value is available.
  /// The value is passed as an argument to the handler.
  ///
  /// The handler is either called directly, if Promise is already resolved, or at a later point in time when the Promise becomes Resolved.
  ///
  /// Multiple handlers can be registered by calling `then` multiple times.
  ///
  /// ## Execution order
  /// Handlers registered with `then` are called in the order they have been registered.
  /// These are interleaved with the other success handlers registered via `finally` or `map`.
  ///
  /// ## Dispatch queue
  /// The handler is synchronously called on the current thread when Promise is already Resolved.
  /// Or, when Promise is resolved later on, the handler is called synchronously on the thread where `PromiseSource.resolve` is called.
  @discardableResult
  public func then(handler: @escaping (Value) -> Void) -> Promise<Value> {

    let resultHandler: (Result<Value, Error>) -> Void = { result in
      switch result {
      case .Value(let value):
        handler(value)
      case .Error:
        break
      }
    }

    source.addOrCallResultHandler(handler: resultHandler)

    return self
  }

  /// Register a handler to be called when error is available.
  /// The error is passed as an argument to the handler.
  ///
  /// The handler is either called directly, if Promise is already rejected, or at a later point in time when the Promise becomes Rejected.
  ///
  /// Multiple handlers can be registered by calling `trap` multiple times.
  ///
  /// ## Execution order
  /// Handlers registered with `trap` are called in the order they have been registered.
  /// These are interleaved with the other failure handlers registered via `finally` or `mapError`.
  ///
  /// ## Dispatch queue
  /// The handler is synchronously called on the current thread when Promise is already Rejected.
  /// Or, when Promise is rejected later on, the handler is called synchronously on the thread where `PromiseSource.reject` is called.
  @discardableResult
  public func trap(handler: @escaping (Error) -> Void) -> Promise<Value> {

    let resultHandler: (Result<Value, Error>) -> Void = { result in
      switch result {
      case .Value:
        break
      case .Error(let error):
        handler(error)
      }
    }

    source.addOrCallResultHandler(handler: resultHandler)

    return self
  }

  /// Register a handler to be called when Promise is resolved _or_ rejected.
  /// No argument is passed to the handler.
  ///
  /// The handler is either called directly, if Promise is already resolved or rejected,
  /// or at a later point in time when the Promise becomes Resolved or Rejected.
  ///
  /// Multiple handlers can be registered by calling `finally` multiple times.
  ///
  /// ## Execution order
  /// Handlers registered with `finally` are called in the order they have been registered.
  /// These are interleaved with the other result handlers registered via `then` or `trap`.
  ///
  /// ## Dispatch queue
  /// The handler is synchronously called on the current thread when Promise is already Resolved or Rejected.
  /// Or, when Promise is resolved or rejected later on,
  /// the handler is called synchronously on the thread where `PromiseSource.resolve` or `PromiseSource.reject` is called.
  @discardableResult
  public func finally(handler: @escaping () -> Void) -> Promise<Value> {

    let resultHandler: (Result<Value, Error>) -> Void = { _ in
      handler()
    }

    source.addOrCallResultHandler(handler: resultHandler)

    return self
  }

  /// Register a handler to be called when Promise is resolved _or_ rejected.
  /// A `Result<Valule, Error>` argument is passed to the handler.
  ///
  /// The handler is either called directly, if Promise is already resolved or rejected,
  /// or at a later point in time when the Promise becomes Resolved or Rejected.
  ///
  /// Multiple handlers can be registered by calling `finally` multiple times.
  ///
  /// ## Execution order
  /// Handlers registered with `finally` are called in the order they have been registered.
  /// These are interleaved with the other result handlers registered via `then` or `trap`.
  ///
  /// ## Dispatch queue
  /// The handler is synchronously called on the current thread when Promise is already Resolved or Rejected.
  /// Or, when Promise is resolved or rejected later on,
  /// the handler is called synchronously on the thread where `PromiseSource.resolve` or `PromiseSource.reject` is called.
  public func finallyResult(handler: @escaping (Result<Value, Error>) -> Void) -> Promise<Value> {

    source.addOrCallResultHandler(handler: handler)

    return self
  }


  // MARK: Dispatch methods

  /// Returns a Promise that dispatches its handlers on the specified dispatch queue.

  public func dispatch(on queue: DispatchQueue) -> Promise<Value> {
    return dispatch(on: .OnQueue(queue))
  }

  /// Returns a Promise that dispatches its handlers on the main dispatch queue.

  public func dispatchMain() -> Promise<Value> {
    return dispatch(on: .main)
  }

  private func dispatch(on dispatch: DispatchMethod) -> Promise<Value> {
    let resultSource = PromiseSource<Value>(state: .Unresolved, dispatch: dispatch, warnUnresolvedDeinit: true)

    source.addOrCallResultHandler(handler: resultSource.resolveResult)

    return resultSource.promise
  }


  // MARK: - Value combinators

  /// Return a Promise containing the results of mapping `transform` over the value of `self`.

  public func map<NewValue>(transform: @escaping (Value) -> NewValue) -> Promise<NewValue> {
    let resultSource = PromiseSource<NewValue>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

    let handler: (Result<Value, Error>) -> Void = { result in
      switch result {
      case .Value(let value):
        let transformed = transform(value)
        resultSource.resolve(value: transformed)
      case .Error(let error):
        resultSource.reject(error: error)
      }
    }

    source.addOrCallResultHandler(handler: handler)

    return resultSource.promise
  }

  /// Returns the flattened result of mapping `transform` over the value of `self`.

  public func flatMap<NewValue>(transform: @escaping (Value) -> Promise<NewValue>) -> Promise<NewValue> {
    let resultSource = PromiseSource<NewValue>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

    let handler: (Result<Value, Error>) -> Void = { result in
      switch result {
      case .Value(let value):
        let transformedPromise = transform(value)
        transformedPromise
          .then(handler: resultSource.resolve)
          .trap(handler: resultSource.reject)
      case .Error(let error):
        resultSource.reject(error: error)
      }
    }

    source.addOrCallResultHandler(handler: handler)

    return resultSource.promise
  }


  // MARK: Error combinators

   /// Return a Promise containing the results of mapping `transform` over the error of `self`.
 
   public func mapError(transform: @escaping (Error) -> Error) -> Promise<Value> {
      let resultSource = PromiseSource<Value>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

      let handler: (Result<Value, Error>) -> Void = { result in
         switch result {
         case .Value(let value):
            resultSource.resolve(value: value)
         case .Error(let error):
            let transformed = transform(error)
            resultSource.reject(error: transformed)
         }
      }

      source.addOrCallResultHandler(handler: handler)

      return resultSource.promise
   }

   /// Returns the flattened result of mapping `transform` over the error of `self`.
 
   public func flatMapError(transform: @escaping (Error) -> Promise<Value>) -> Promise<Value> {
      let resultSource = PromiseSource<Value>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

      let handler: (Result<Value, Error>) -> Void = { result in
         switch result {
         case .Value(let value):
            resultSource.resolve(value: value)
         case .Error(let error):
            let transformedPromise = transform(error)
            transformedPromise
               .then(handler: resultSource.resolve)
               .trap(handler: resultSource.reject)
         }
      }

      source.addOrCallResultHandler(handler: handler)
      
      return resultSource.promise
   }

  // MARK: Result combinators

  /// Return a Promise containing the results of mapping `transform` over the result of `self`.

    public func mapResult<NewValue, NewError: Error>(transform: @escaping (Result<Value, Error>) -> Result<NewValue, NewError>) -> Promise<NewValue> {
    let resultSource = PromiseSource<NewValue>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

    let handler: (Result<Value, Error>) -> Void = { result in
      switch transform(result) {
      case .Value(let value):
        resultSource.resolve(value: value)
      case .Error(let error):
        resultSource.reject(error: error)
      }
    }

    source.addOrCallResultHandler(handler: handler)

    return resultSource.promise
  }

  /// Returns the flattened result of mapping `transform` over the result of `self`.

    public func flatMapResult<NewValue>(transform: @escaping (Result<Value, Error>) -> Promise<NewValue>) -> Promise<NewValue> {
    let resultSource = PromiseSource<NewValue>(state: .Unresolved, dispatch: source.dispatchMethod, warnUnresolvedDeinit: true)

    let handler: (Result<Value, Error>) -> Void = { result in
      let transformedPromise = transform(result)
      transformedPromise
        .then(handler: resultSource.resolve)
        .trap(handler: resultSource.reject)
    }

    source.addOrCallResultHandler(handler: handler)

    return resultSource.promise
  }
}
