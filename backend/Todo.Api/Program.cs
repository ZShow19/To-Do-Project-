using Microsoft.EntityFrameworkCore;
using Todo.Api.Data;
using Todo.Api.Models;
using Todo.Api.Services;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<TodoDbContext>(options =>
{
    var provider = builder.Configuration["DatabaseProvider"]?.Trim().ToLowerInvariant() ?? "sqlite";
    var sqliteConnection = builder.Configuration.GetConnectionString("Sqlite") ?? "Data Source=todo.db";
    var postgresConnection = builder.Configuration.GetConnectionString("Postgres")
        ?? builder.Configuration.GetConnectionString("PostgreSql");

    if (provider is "postgres" or "postgresql" or "npgsql")
    {
        if (string.IsNullOrWhiteSpace(postgresConnection))
            throw new InvalidOperationException("A PostgreSQL connection string is required when DatabaseProvider is PostgreSQL.");
        options.UseNpgsql(postgresConnection);
    }
    else if (provider is "sqlite" or "sqlite3")
    {
        options.UseSqlite(sqliteConnection);
    }
    else
    {
        throw new InvalidOperationException($"Unsupported DatabaseProvider '{provider}'. Use Sqlite or PostgreSQL.");
    }
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(options => options.AddPolicy("Frontend", policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>();
    if (origins is { Length: > 0 }) policy.WithOrigins(origins);
    else policy.AllowAnyOrigin();
    policy.AllowAnyHeader().AllowAnyMethod();
}));

var app = builder.Build();
app.UseCors("Frontend");
app.MapGet("/api/health", () => Results.Ok(new { status = "ok", database = builder.Configuration["DatabaseProvider"] ?? "Sqlite", utc = DateTime.UtcNow }));
if (app.Environment.IsDevelopment()) { app.UseSwagger(); app.UseSwaggerUI(); }
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
    await db.Database.EnsureCreatedAsync();
    await SeedData.InitializeAsync(db);
}

app.MapGet("/api/tasks", async (TodoDbContext db, string? status, string? search, string? category) =>
{
    var query = db.Tasks.AsNoTracking().AsQueryable();
    if (!string.IsNullOrWhiteSpace(search))
    {
        search = search.Trim();
        query = query.Where(x => x.Title.Contains(search) || x.Description.Contains(search));
    }
    if (!string.IsNullOrWhiteSpace(category)) query = query.Where(x => x.Category == category.Trim());
    switch (status?.Trim().ToLowerInvariant())
    {
        case "completed": query = query.Where(x => x.IsCompleted); break;
        case "active": query = query.Where(x => !x.IsCompleted); break;
        case "overdue": query = query.Where(x => !x.IsCompleted && x.DueDateUtc < DateTime.UtcNow); break;
    }
    return Results.Ok(await query.OrderBy(x => x.IsCompleted).ThenBy(x => x.DueDateUtc).ThenByDescending(x => x.CreatedAtUtc).ToListAsync());
});
app.MapPost("/api/tasks", async (TodoTask task, TodoDbContext db) =>
{
    task.Title = task.Title?.Trim() ?? string.Empty;
    if (task.Title.Length == 0) return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(task.Title)] = ["Title is required."] });
    task.Description = task.Description?.Trim() ?? string.Empty;
    task.Category = string.IsNullOrWhiteSpace(task.Category) ? "Личное" : task.Category.Trim();
    task.Priority = string.IsNullOrWhiteSpace(task.Priority) ? "Средний" : task.Priority.Trim();
    task.Id = Guid.NewGuid(); task.CreatedAtUtc = DateTime.UtcNow; task.DueDateUtc = NormalizeUtc(task.DueDateUtc);
    task.CompletedAtUtc = task.IsCompleted ? DateTime.UtcNow : null;
    db.Tasks.Add(task); await db.SaveChangesAsync(); return Results.Created($"/api/tasks/{task.Id}", task);
});
app.MapPut("/api/tasks/{id:guid}", async (Guid id, TodoTask input, TodoDbContext db) =>
{
    var task = await db.Tasks.FindAsync(id); if (task is null) return Results.NotFound();
    input.Title = input.Title?.Trim() ?? string.Empty;
    if (input.Title.Length == 0) return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(input.Title)] = ["Title is required."] });
    task.Title = input.Title; task.Description = input.Description?.Trim() ?? string.Empty;
    task.Category = string.IsNullOrWhiteSpace(input.Category) ? "Личное" : input.Category.Trim();
    task.Priority = string.IsNullOrWhiteSpace(input.Priority) ? "Средний" : input.Priority.Trim();
    task.DueDateUtc = NormalizeUtc(input.DueDateUtc);
    await db.SaveChangesAsync(); return Results.Ok(task);
});
app.MapPatch("/api/tasks/{id:guid}/complete", async (Guid id, CompleteTaskRequest input, TodoDbContext db) =>
{
    var task = await db.Tasks.FindAsync(id); if (task is null) return Results.NotFound(); task.IsCompleted = input.IsCompleted; task.CompletedAtUtc = input.IsCompleted ? DateTime.UtcNow : null; await db.SaveChangesAsync(); return Results.Ok(task);
});
app.MapDelete("/api/tasks/{id:guid}", async (Guid id, TodoDbContext db) => { var task = await db.Tasks.FindAsync(id); if (task is null) return Results.NotFound(); db.Tasks.Remove(task); await db.SaveChangesAsync(); return Results.NoContent(); });

app.MapGet("/api/daily-logs/{date}", async (DateOnly date, TodoDbContext db) => Results.Ok(await db.DailyLogs.AsNoTracking().FirstOrDefaultAsync(x => x.Date == date) ?? new DailyLog { Date = date }));
app.MapPut("/api/daily-logs/{date}", async (DateOnly date, DailyLog input, TodoDbContext db) =>
{
    var log = await db.DailyLogs.FindAsync(date); if (log is null) { log = new DailyLog { Date = date }; db.DailyLogs.Add(log); }
    log.ProductivityScore = Math.Clamp(input.ProductivityScore, 1, 10); log.Note = (input.Note ?? string.Empty).Trim(); await db.SaveChangesAsync(); return Results.Ok(log);
});

app.MapGet("/api/products", async (TodoDbContext db, string? search) => { var query = db.FoodProducts.AsNoTracking().AsQueryable(); if (!string.IsNullOrWhiteSpace(search)) query = query.Where(x => x.Name.Contains(search.Trim())); return Results.Ok(await query.OrderBy(x => x.Name).ToListAsync()); });
app.MapPost("/api/products", async (FoodProduct product, TodoDbContext db) =>
{
    product.Name = product.Name?.Trim() ?? string.Empty;
    if (product.Name.Length == 0) return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(product.Name)] = ["Name is required."] });
    if (product.CaloriesPer100g < 0 || product.ProteinPer100g < 0 || product.FatPer100g < 0 || product.CarbsPer100g < 0)
        return Results.ValidationProblem(new Dictionary<string, string[]> { ["nutrition"] = ["Nutritional values cannot be negative."] });
    product.Id = Guid.NewGuid(); product.IsCustom = true; db.FoodProducts.Add(product); await db.SaveChangesAsync(); return Results.Created($"/api/products/{product.Id}", product);
});
app.MapGet("/api/meals", async (DateOnly? date, TodoDbContext db) =>
{
    var requestedDate = date ?? DateOnly.FromDateTime(DateTime.UtcNow);
    return Results.Ok(await db.MealEntries.AsNoTracking().Include(x => x.Product).Where(x => x.Date == requestedDate).OrderBy(x => x.MealType).ToListAsync());
});
app.MapPost("/api/meals", async (MealEntry entry, TodoDbContext db) =>
{
    if (entry.WeightGrams <= 0) return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(entry.WeightGrams)] = ["WeightGrams must be greater than zero."] });
    if (entry.Date == default) entry.Date = DateOnly.FromDateTime(DateTime.UtcNow);
    entry.MealType = string.IsNullOrWhiteSpace(entry.MealType) ? "Перекус" : entry.MealType.Trim();
    entry.Id = Guid.NewGuid(); var product = await db.FoodProducts.FindAsync(entry.ProductId); if (product is null) return Results.BadRequest("Продукт не найден");
    entry.CalculatedCalories = product.CaloriesPer100g * entry.WeightGrams / 100; entry.CalculatedProtein = product.ProteinPer100g * entry.WeightGrams / 100; entry.CalculatedFat = product.FatPer100g * entry.WeightGrams / 100; entry.CalculatedCarbs = product.CarbsPer100g * entry.WeightGrams / 100;
    db.MealEntries.Add(entry); await db.SaveChangesAsync(); return Results.Ok(await db.MealEntries.Include(x => x.Product).FirstAsync(x => x.Id == entry.Id));
});
app.MapDelete("/api/meals/{id:guid}", async (Guid id, TodoDbContext db) => { var entry = await db.MealEntries.FindAsync(id); if (entry is null) return Results.NotFound(); db.MealEntries.Remove(entry); await db.SaveChangesAsync(); return Results.NoContent(); });

app.MapGet("/api/settings", async (TodoDbContext db) => Results.Ok(await db.UserSettings.FindAsync(1) ?? new UserSettings { Id = 1 }));
app.MapPut("/api/settings", async (UserSettings input, TodoDbContext db) =>
{
    var settings = await db.UserSettings.FindAsync(1); if (settings is null) { settings = new UserSettings { Id = 1 }; db.UserSettings.Add(settings); }
    if (input.TargetCalories < 0 || input.TargetProtein < 0 || input.TargetFat < 0 || input.TargetCarbs < 0 || input.MinimumTasksPerDay < 0)
        return Results.ValidationProblem(new Dictionary<string, string[]> { ["targets"] = ["Targets cannot be negative."] });
    settings.ThemeMode = string.IsNullOrWhiteSpace(input.ThemeMode) ? "system" : input.ThemeMode.Trim();
    settings.TargetCalories = input.TargetCalories; settings.TargetProtein = input.TargetProtein; settings.TargetFat = input.TargetFat; settings.TargetCarbs = input.TargetCarbs; settings.MinimumTasksPerDay = input.MinimumTasksPerDay; await db.SaveChangesAsync(); return Results.Ok(settings);
});
app.MapGet("/api/stats", async (DateOnly? from, DateOnly? to, TodoDbContext db) =>
{
    var end = to ?? from ?? DateOnly.FromDateTime(DateTime.UtcNow);
    var start = from ?? end.AddDays(-29);
    if (start > end) return Results.BadRequest("from must be on or before to");
    return Results.Ok(await StatsService.BuildAsync(db, start, end));
});
app.MapGet("/api/export", async (TodoDbContext db) => Results.Ok(new { exportedAtUtc = DateTime.UtcNow, tasks = await db.Tasks.AsNoTracking().ToListAsync(), dailyLogs = await db.DailyLogs.AsNoTracking().ToListAsync(), products = await db.FoodProducts.AsNoTracking().ToListAsync(), meals = await db.MealEntries.AsNoTracking().ToListAsync(), settings = await db.UserSettings.AsNoTracking().FirstOrDefaultAsync() }));

static DateTime? NormalizeUtc(DateTime? value) => value?.Kind switch
{
    null => null,
    DateTimeKind.Utc => value,
    DateTimeKind.Local => value.Value.ToUniversalTime(),
    _ => DateTime.SpecifyKind(value.Value, DateTimeKind.Utc)
};

app.Run();
public record CompleteTaskRequest(bool IsCompleted);
