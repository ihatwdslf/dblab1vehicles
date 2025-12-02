using System;
using System.Threading.Tasks;
using Npgsql;

namespace Dblab1Vehicles
{
    public class PgUnitOfWork : IAsyncDisposable
    {
        private readonly NpgsqlConnection _connection;

        public UserRepository Users { get; }
        public DriverRepository Drivers { get; }
        public VehicleRepository Vehicles { get; }
        public TripRepository Trips { get; }

        public PgUnitOfWork(string connectionString)
        {
            _connection = new NpgsqlConnection(connectionString);
            _connection.Open();

            Users = new UserRepository(_connection);
            Drivers = new DriverRepository(_connection);
            Vehicles = new VehicleRepository(_connection);
            Trips = new TripRepository(_connection);
        }

        public async ValueTask DisposeAsync()
        {
            if (_connection != null)
            {
                await _connection.DisposeAsync();
            }
        }
    }
}
