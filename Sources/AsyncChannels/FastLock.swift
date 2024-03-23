import Foundation

#if canImport(Darwin)
struct FastLock {
    var slock = OSSpinLock()
    
    mutating func lock() {
        OSSpinLockLock(&slock)
    }
    
    mutating func unlock() {
        OSSpinLockUnlock(&slock)
    }
}

#else

class FastLock {

    var m: pthread_mutex_t = {
        var m = pthread_mutex_t()
        pthread_mutex_init(&m, nil)
        return m
    }()

    func lock() {
        pthread_mutex_lock(&m)
    }
    
    func unlock() {
        pthread_mutex_unlock(&m)
    }
}

#endif
