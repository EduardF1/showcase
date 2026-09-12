namespace Showcase.Results;

/// <summary>
/// The expected failures of an operation, as data.
///
/// This is not a general replacement for exceptions. It carries the outcomes a caller can act on:
/// a rejected booking, a name already taken, a rule that says no. Everything the caller cannot act
/// on (a dropped connection, a serialisation fault, a bug) still throws, because a caller that
/// cannot do anything but log it should not be made to write that branch.
/// </summary>
public readonly record struct Error(string Code, string Message)
{
    /// <summary>
    /// The code is what a handler switches on and what a client can be given; the message is for a
    /// human. Keeping them separate stops a caller matching on prose, which is how an error message
    /// becomes an accidental API that cannot be reworded.
    /// </summary>
    public override string ToString() => $"{Code}: {Message}";
}

public readonly struct Result<T>
{
    private readonly T _value;
    private readonly Error _error;

    public bool IsSuccess { get; }

    public Error Error => IsSuccess
        ? throw new InvalidOperationException("Result is a success; there is no error to read.")
        : _error;

    public T Value => IsSuccess
        ? _value
        : throw new InvalidOperationException($"Result is a failure ({_error.Code}); there is no value to read.");

    private Result(T value)
    {
        _value = value;
        _error = default;
        IsSuccess = true;
    }

    private Result(Error error)
    {
        _value = default!;
        _error = error;
        IsSuccess = false;
    }

    public static Result<T> Ok(T value) => new(value);

    public static Result<T> Fail(string code, string message) => new(new Error(code, message));

    /// <summary>
    /// Both branches are required. There is no overload that defaults the failure case, because a
    /// defaulted failure branch is how a rejection turns into an empty page with a 200 beside it.
    /// </summary>
    public TOut Match<TOut>(Func<T, TOut> onSuccess, Func<Error, TOut> onFailure) =>
        IsSuccess ? onSuccess(_value) : onFailure(_error);
}
