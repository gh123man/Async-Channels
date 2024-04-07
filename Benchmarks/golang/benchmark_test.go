package main

import (
	"sync"
	"testing"
)

func BenchmarkSPSC(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(1, 1, 1_000_000, 0)
	}
}

func BenchmarkMPSC(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(5, 1, 1_000_000, 0)
	}
}

func BenchmarkSPMC(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(1, 5, 1_000_000, 0)
	}
}

func BenchmarkMPMC(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(1, 5, 1_000_000, 0)
	}
}

func BenchmarkMPSCWriteContention(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(1000, 1, 1_000_000, 0)
	}
}

func BenchmarkSPSCBuffered(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(1, 1, 1_000_000, 100)
	}
}

func BenchmarkMPSCBuffered(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(5, 1, 1_000_000, 100)
	}
}

func BenchmarkSPMCBuffered(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(1, 5, 1_000_000, 100)
	}
}

func BenchmarkMPMCBuffered(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(1, 5, 1_000_000, 100)
	}
}

func BenchmarkMPSCWriteContentionBuffered(b *testing.B) {
	for i := 0; i < b.N; i++ {
		benchmarkMPMC(1000, 1, 1_000_000, 100)
	}
}

func BenchmarkSyncRw(b *testing.B) {
	for i := 0; i < b.N; i++ {
		a := make(chan int, 1)

		for k := 0; k < 5_000_000; k++ {
			a <- i
			<-a
		}
	}
}

func BenchmarkMultiSelect(b *testing.B) {
	for i := 0; i < b.N; i++ {
		a := make(chan int)
		bc := make(chan int)
		c := make(chan int)
		d := make(chan int)
		e := make(chan int)
		f := make(chan int)

		for _, channel := range []chan int{a, bc, c, d, e, f} {
			go func(ch chan int) {
				for n := 0; n < 100_000; n++ {
					ch <- 1
				}
			}(channel)
		}

		sum := 0
		for sum < 6*100_000 {
			select {
			case v := <-a:
				sum += v
			case v := <-bc:
				sum += v
			case v := <-c:
				sum += v
			case v := <-d:
				sum += v
			case v := <-e:
				sum += v
			case v := <-f:
				sum += v
			}
		}
	}
}

func benchmarkMPMC(producers int, consumers int, writes int, buffer int) {
	ch := make(chan int, buffer)
	var writeGroup sync.WaitGroup
	writeGroup.Add(producers)

	var readGroup sync.WaitGroup
	readGroup.Add(consumers)

	for p := 0; p < producers; p++ {
		go func() {
			for i := 0; i < writes/producers; i++ {
				ch <- i
			}
			writeGroup.Done()
		}()
	}
	for c := 0; c < consumers; c++ {
		go func() {
			for range ch {
			}
			readGroup.Done()
		}()
	}
	writeGroup.Wait()
	close(ch)
	readGroup.Wait()
}
