using Microsoft.AspNetCore.Http;
using Showcase.Bookings;
using Showcase.Results;
using Xunit;

namespace Showcase.Tests;

public sealed class FakeBookingRepository : IBookingRepository
{
    public bool Reserved { get; init; }
    public Exception? Throw { get; init; }
    public List<Booking> Saved { get; } = [];

    public Task<bool> IsReservedAsync(Guid vehicleId, DateOnly from, DateOnly to, CancellationToken ct) =>
        Throw is null ? Task.FromResult(Reserved) : Task.FromException<bool>(Throw);

    public Task<Booking> SaveAsync(Booking booking, CancellationToken ct)
    {
        Saved.Add(booking);
        return Task.FromResult(booking);
    }
}

public class ResultTests
{
    [Fact]
    public void Match_runs_only_the_branch_that_applies()
    {
        Assert.Equal("ok:5", Result<int>.Ok(5).Match(v => $"ok:{v}", e => $"fail:{e.Code}"));
        Assert.Equal("fail:nope", Result<int>.Fail("nope", "No.").Match(v => $"ok:{v}", e => $"fail:{e.Code}"));
    }

    [Fact]
    public void Reading_the_wrong_side_throws_instead_of_returning_a_default()
    {
        Assert.Throws<InvalidOperationException>(() => Result<int>.Ok(5).Error);
        Assert.Throws<InvalidOperationException>(() => Result<int>.Fail("nope", "No.").Value);
    }

    [Fact]
    public void Error_keeps_code_and_message_apart()
    {
        var error = Result<int>.Fail("name_taken", "That name is taken.").Error;
        Assert.Equal("name_taken", error.Code);
        Assert.Equal("That name is taken.", error.Message);
    }
}

public class BookingServiceTests
{
    private static readonly DateOnly Monday = new(2026, 10, 19);
    private static BookingRequest Request(int days) => new(Guid.NewGuid(), Monday, Monday.AddDays(days));

    [Fact]
    public async Task Reserved_vehicle_is_an_expected_failure_in_the_result()
    {
        var repo = new FakeBookingRepository { Reserved = true };
        var result = await new BookingService(repo).BookAsync(Request(2), CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal(BookingService.VehicleUnavailable, result.Error.Code);
        Assert.Empty(repo.Saved);
    }

    [Fact]
    public async Task Inverted_dates_are_an_expected_failure_in_the_result()
    {
        var result = await new BookingService(new FakeBookingRepository()).BookAsync(Request(0), CancellationToken.None);

        Assert.Equal(BookingService.DatesInverted, result.Error.Code);
    }

    [Fact]
    public async Task Infrastructure_failure_throws_and_is_not_folded_into_the_result()
    {
        var repo = new FakeBookingRepository { Throw = new TimeoutException("connection dropped") };

        await Assert.ThrowsAsync<TimeoutException>(
            () => new BookingService(repo).BookAsync(Request(2), CancellationToken.None));
    }

    [Fact]
    public async Task Free_vehicle_is_saved_and_returned()
    {
        var repo = new FakeBookingRepository();
        var request = Request(2);
        var result = await new BookingService(repo).BookAsync(request, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(request.VehicleId, result.Value.VehicleId);
        Assert.Single(repo.Saved);
    }
}

public class BookingEndpointTests
{
    private static readonly DateOnly Monday = new(2026, 10, 19);

    private static async Task<int?> StatusFor(FakeBookingRepository repo, int days)
    {
        var request = new BookingRequest(Guid.NewGuid(), Monday, Monday.AddDays(days));
        var result = await BookingEndpoint.Handle(request, new BookingService(repo), CancellationToken.None);
        return Assert.IsAssignableFrom<IStatusCodeHttpResult>(result).StatusCode;
    }

    [Fact]
    public async Task Maps_success_to_201() =>
        Assert.Equal(StatusCodes.Status201Created, await StatusFor(new FakeBookingRepository(), 2));

    [Fact]
    public async Task Maps_reserved_vehicle_to_409() =>
        Assert.Equal(StatusCodes.Status409Conflict, await StatusFor(new FakeBookingRepository { Reserved = true }, 2));

    [Fact]
    public async Task Maps_inverted_dates_to_400() =>
        Assert.Equal(StatusCodes.Status400BadRequest, await StatusFor(new FakeBookingRepository(), -1));

    [Fact]
    public async Task Lets_infrastructure_failure_reach_the_boundary_uncaught()
    {
        // No catch in the handler: the exception travels to the framework, which turns it into a 500.
        var repo = new FakeBookingRepository { Throw = new TimeoutException("connection dropped") };
        await Assert.ThrowsAsync<TimeoutException>(() => StatusFor(repo, 2));
    }
}
