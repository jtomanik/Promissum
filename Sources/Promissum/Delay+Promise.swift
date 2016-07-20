//
//  Delay.swift
//  Promissum
//
//  Created by Tom Lokhorst on 2015-01-12.
//  Copyright (c) 2015 Tom Lokhorst. All rights reserved.
//

import Foundation
import Dispatch

/// Wrapper around `dispatch_after`, with a seconds parameter.
public func delay(seconds: NSTimeInterval, queue: dispatch_queue_t! = dispatch_get_main_queue(), block: dispatch_block_t!) {
  let when = dispatch_time(DISPATCH_TIME_NOW, Int64(seconds * Double(NSEC_PER_SEC)))

  dispatch_after(when, queue, block)
}

/// Create a Promise that resolves with the specified value after the specified number of seconds.
public func delayPromise<Value>(seconds: NSTimeInterval, value: Value, queue: dispatch_queue_t! = dispatch_get_main_queue()) -> Promise<Value> {
  let source = PromiseSource<Value>()

  delay(seconds: seconds, queue: queue) {
    source.resolve(value: value)
  }

  return source.promise
}

/// Create a Promise that rejects with the specified error after the specified number of seconds.
public func delayErrorPromise<Value>(seconds: NSTimeInterval, error: ErrorProtocol, queue: dispatch_queue_t! = dispatch_get_main_queue()) -> Promise<Value> {
  let source = PromiseSource<Value>()

  delay(seconds: seconds, queue: queue) {
    source.reject(error: error)
  }

  return source.promise
}

/// Create a Promise that resolves after the specified number of seconds.
public func delayPromise(seconds: NSTimeInterval, queue: dispatch_queue_t! = dispatch_get_main_queue()) -> Promise<Void> {
  return delayPromise(seconds: seconds, value: (), queue: queue)
}

extension Promise {

  /// Return a Promise with the resolve or reject delayed by the specified number of seconds.
  public func delay(seconds: NSTimeInterval) -> Promise<Value> {
    return self
      .flatMap { value in
        return delayPromise(seconds: seconds).map { value }
      }
      .flatMapError { error in
        return delayPromise(seconds: seconds).flatMap { Promise(error: error) }
      }
  }
}
