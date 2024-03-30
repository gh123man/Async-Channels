FROM swift:5.9-jammy as build

COPY . .

WORKDIR Benchmarks
RUN swift build -c release

ENTRYPOINT [ ".build/release/Benchmarks" ]