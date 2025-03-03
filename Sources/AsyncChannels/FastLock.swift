import Foundation

#if canImport(Darwin)
class FastLock {
    let unfairLock = {
        let l = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        l.initialize(to: os_unfair_lock())
        return l
    }()
    
    deinit {
        unfairLock.deallocate()
    }

    @inline(__always)
    func lock() {
        os_unfair_lock_lock(unfairLock)
    }
   
    @inline(__always)
    func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
}

#else

class FastLock {

    var m: pthread_mutex_t = {
        var m = pthread_mutex_t()
        pthread_mutex_init(&m, nil)
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
