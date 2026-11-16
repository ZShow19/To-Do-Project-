using Microsoft.EntityFrameworkCore;
using Todo.Api.Models;

namespace Todo.Api.Data;
public sealed class TodoDbContext(DbContextOptions<TodoDbContext> options) : DbContext(options)
{
    public DbSet<TodoTask> Tasks => Set<TodoTask>(); public DbSet<DailyLog> DailyLogs => Set<DailyLog>(); public DbSet<FoodProduct> FoodProducts => Set<FoodProduct>(); public DbSet<MealEntry> MealEntries => Set<MealEntry>(); public DbSet<UserSettings> UserSettings => Set<UserSettings>();
    protected override void OnModelCreating(ModelBuilder modelBuilder) => modelBuilder.ApplyConfigurationsFromAssembly(typeof(TodoDbContext).Assembly);
}
