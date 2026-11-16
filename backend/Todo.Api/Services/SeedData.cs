using Microsoft.EntityFrameworkCore; using Todo.Api.Data; using Todo.Api.Models;
namespace Todo.Api.Services;
public static class SeedData
{
    public static async Task InitializeAsync(TodoDbContext db)
    {
        if (!await db.UserSettings.AnyAsync()) db.UserSettings.Add(new UserSettings { Id = 1 });
        if (!await db.FoodProducts.AnyAsync()) db.FoodProducts.AddRange(Product("Куриная грудка", 165, 31, 3.6, 0), Product("Яйцо", 157, 13, 11, 1.1), Product("Рис", 344, 6.7, .7, 78), Product("Гречка", 343, 13.6, 3.3, 71.5), Product("Овсянка", 366, 12.3, 6.1, 59.5), Product("Хлебцы", 310, 10, 2, 65), Product("Банан", 89, 1.1, .3, 23), Product("Творог 5%", 121, 17, 5, 3), Product("Мёд", 304, .3, 0, 82), Product("Орехи", 607, 20, 54, 21));
        await db.SaveChangesAsync();
    }
    private static FoodProduct Product(string n, double c, double p, double f, double h) => new() { Id = Guid.NewGuid(), Name = n, CaloriesPer100g = c, ProteinPer100g = p, FatPer100g = f, CarbsPer100g = h };
}
