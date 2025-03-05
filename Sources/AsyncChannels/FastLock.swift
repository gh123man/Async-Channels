import Foundation

#if canImport(Darwin)
class FastLock {
    private var spinlock = OSSpinLock()

    @inline(__always)
    func lock() {
        OSSpinLockLock(&spinlock)
    }

    @inline(__always)
    func unlock() {
        OSSpinLockUnlock(&spinlock)
    }
}

#else

class FastLock {

    private var spinlock: pthread_spinlock_t = {
        var lock = pthread_spinlock_t()
        pthread_spin_init(&lock, 0)
        return lock
    }()

    deinit {
        pthread_spin_destroy(&spinlock)
    }

    @inline(__always)
    func lock() {
        pthread_spin_lock(&spinlock)
    }

    @inline(__always)
    func unlock() {
        pthread_spin_unlock(&spinlock)
    }


      /*   var m: pthread_mutex_t = {
      var m = pthread_mutex_t()
      var attr = pthread_mutexattr_t()
      pthread_mutexattr_init(&attr)
      pthread_mutexattr_settype(&attr, 3) // Faster under contention
      pthread_mutex_init(&m, &attr)
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
  }*/
}

#endif
