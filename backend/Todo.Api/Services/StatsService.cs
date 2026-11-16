using Microsoft.EntityFrameworkCore; using Todo.Api.Data; using Todo.Api.Models;
namespace Todo.Api.Services;
public static class StatsService
{
    public static async Task<StatsResponse> BuildAsync(TodoDbContext db, DateOnly from, DateOnly to)
    {
        if (from > to) throw new ArgumentException("The start date must be on or before the end date.");

        var start = from.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var end = to.AddDays(1).ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var tasks = await db.Tasks.AsNoTracking()
            .Where(x => x.DueDateUtc.HasValue && x.DueDateUtc >= start && x.DueDateUtc < end)
            .ToListAsync();
        var logs = await db.DailyLogs.AsNoTracking()
            .Where(x => x.Date >= from && x.Date <= to)
            .ToDictionaryAsync(x => x.Date);
        var meals = await db.MealEntries.AsNoTracking()
            .Where(x => x.Date >= from && x.Date <= to)
            .ToListAsync();
        var days = new List<DayStat>(); var points = new List<MetricPoint>();
        for (var date = from; date <= to; date = date.AddDays(1))
        {
            var dayTasks = tasks.Where(x => x.DueDateUtc.HasValue &&
                DateOnly.FromDateTime(DateTime.SpecifyKind(x.DueDateUtc.Value, DateTimeKind.Utc)) == date).ToList();
            var planned = dayTasks.Count;
            var done = dayTasks.Count(x => x.IsCompleted);
            var status = done == 0 ? "empty" : planned > 0 && done == planned ? "complete" : "partial";
            logs.TryGetValue(date, out var log);
            var dayMeals = meals.Where(x => x.Date == date).ToList();
            var calories = dayMeals.Sum(x => x.CalculatedCalories);
            var protein = dayMeals.Sum(x => x.CalculatedProtein);
            var fat = dayMeals.Sum(x => x.CalculatedFat);
            var carbs = dayMeals.Sum(x => x.CalculatedCarbs);
            days.Add(new DayStat(date, planned, done, status, log?.ProductivityScore ?? 0, log?.Note ?? "", calories, protein, fat, carbs));
            points.Add(new MetricPoint(date, log?.ProductivityScore ?? 0, planned == 0 ? 0 : done * 100d / planned, done));
        }
        return new StatsResponse(days, points);
    }
}
