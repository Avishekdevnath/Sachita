sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(String message) = Failure<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(String message) failure,
  }) {
    final current = this;
    if (current is Success<T>) {
      return success(current.value);
    }
    return failure((current as Failure<T>).message);
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.message);

  final String message;
}
