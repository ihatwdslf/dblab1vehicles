using System;
using System.Threading.Tasks;

namespace Dblab1Vehicles
{
    class Program
    {
        static async Task Main()
        {
            string connStr = "Host=localhost;Port=5432;Database=dblab1vehicles;Username=postgres;Password=11111111";
            await using var uow = new PgUnitOfWork(connStr);

            var users = await uow.Users.GetAllUsersAsync();
            foreach (var u in users)
            {
                Console.WriteLine($"{u.Id}: {u.Name} ({u.Email})");
            }
        }
    }
}
