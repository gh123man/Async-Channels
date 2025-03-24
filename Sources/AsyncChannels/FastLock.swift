import Foundation

#if canImport(Darwin)
class FastLock {
    let unfairLock = {
        let l = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        l.initialize(to: os_unfair_lock())
        return l
    }()
    
    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    @inlinable
    @inline(__always)
    func lock() {
        os_unfair_lock_lock(unfairLock)
    }
   
    @inlinable
    @inline(__always)
    func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
}

#else

class FastLock {
    var m: pthread_mutex_t = {
      var m = pthread_mutex_t()
      var attr = pthread_mutexattr_t()
      pthread_mutexattr_init(&attr)
      pthread_mutexattr_settype(&attr, 3) // Faster under contention
      precondition(pthread_mutex_init(&m, &attr) == 0, "pthread_mutex_init failed")
      pthread_mutexattr_destroy(&attr)
      return m
  }()

  deinit {
      pthread_mutex_destroy(&m)
  }

  @inline(__always)
  func lock() {
      pthread_mutex_lock(&m)
  }

  @inline(__always)
  func unlock() {
      pthread_mutex_unlock(&m)
  }
}

#endif
