using Showcase.Results;
using HttpResults = Microsoft.AspNetCore.Http.Results;

namespace Showcase.Bookings;

public sealed record BookingRequest(Guid VehicleId, DateOnly From, DateOnly To);

public sealed record Booking(Guid Id, Guid VehicleId, DateOnly From, DateOnly To);

public interface IBookingRepository
{
    /// <summary>Throws on infrastructure failure. That is deliberate, see the class comment below.</summary>
    Task<bool> IsReservedAsync(Guid vehicleId, DateOnly from, DateOnly to, CancellationToken ct);

    Task<Booking> SaveAsync(Booking booking, CancellationToken ct);
}

/// <summary>
/// The service returns the failures a caller can act on and throws the ones it cannot.
///
/// IsReservedAsync throwing on a dropped connection is the point, not an oversight. Wrapping it in
/// a try/catch here would produce a Result whose failure case mixes "this vehicle is taken" with
/// "the database is down", and the endpoint would then have to tell them apart by reading a string.
/// </summary>
public sealed class BookingService(IBookingRepository repository)
{
    public const string VehicleUnavailable = "vehicle_unavailable";
    public const string DatesInverted = "dates_inverted";

    public async Task<Result<Booking>> BookAsync(BookingRequest request, CancellationToken ct)
    {
        if (request.To <= request.From)
        {
            return Result<Booking>.Fail(DatesInverted, "The end date must be after the start date.");
        }

        if (await repository.IsReservedAsync(request.VehicleId, request.From, request.To, ct))
        {
            return Result<Booking>.Fail(VehicleUnavailable, "That vehicle is already booked for those dates.");
        }

        var saved = await repository.SaveAsync(
            new Booking(Guid.NewGuid(), request.VehicleId, request.From, request.To), ct);
        return Result<Booking>.Ok(saved);
    }
}

public static class BookingEndpoint
{
    /// <summary>
    /// No try/catch. An expected failure arrives as a Result and is mapped by code; an unexpected
    /// one travels to the framework's exception handler, is logged once with its stack, and becomes
    /// a 500. One place to look when something breaks, rather than a swallowed catch per handler.
    /// </summary>
    public static async Task<IResult> Handle(
        BookingRequest request, BookingService bookings, CancellationToken ct)
    {
        var result = await bookings.BookAsync(request, ct);
        return ToHttpResult(result);
    }

    /// <summary>The mapping on its own, so a test can hand it a code the service never produces.</summary>
    public static IResult ToHttpResult(Result<Booking> result) =>
        result.Match(
            booking => HttpResults.Created($"/bookings/{booking.Id}", booking),
            error => error.Code switch
            {
                BookingService.VehicleUnavailable => HttpResults.Conflict(new { error.Code, error.Message }),
                BookingService.DatesInverted => HttpResults.BadRequest(new { error.Code, error.Message }),
                // A code nobody mapped is a bug in this switch, not a client error. Saying so is
                // better than defaulting to 400 and blaming the caller for our omission.
                _ => HttpResults.Problem($"Unmapped booking error code: {error.Code}"),
            });
}
