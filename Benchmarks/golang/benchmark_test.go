package main

import (
	"testing"
)

func BenchmarkSingleReaderManyWriter(b *testing.B) {
	for i := 0; i < b.N; i++ {
		a := make(chan int)
		var sum = 0

		for j := 0; j < 100; j++ {
			go func() {
				for k := 0; k < 10000; j++ {
					a <- 1
				}
			}()
		}

		for sum < 1_000_000 {
			sum += <-a
		}
	}
}

func BenchmarkHighConcurrency(b *testing.B) {
	for i := 0; i < b.N; i++ {
		a := make(chan int)
		sum := 0

		for j := 0; j < 1000; j++ {
			go func() {
				for k := 0; k < 1000; k++ {
					a <- 1
				}
			}()
		}

		for sum < 1_000_000 {
			sum += <-a
		}
	}
}

func BenchmarkHighConcurrencyBuffered(b *testing.B) {
	for i := 0; i < b.N; i++ {
		a := make(chan int, 20)
		var sum = 0

		for j := 0; j < 1000; j++ {
			go func() {
				for k := 0; k < 1000; k++ {
					a <- 1
				}
			}()
		}

		for sum < 1_000_000 {
			sum += <-a
		}
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

func BenchmarkSelect(b *testing.B) {
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
