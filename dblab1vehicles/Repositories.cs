using Npgsql;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Dblab1Vehicles
{
    public interface IUserRepository
    {
        Task<IEnumerable<UserDto>> GetAllUsersAsync(CancellationToken ct = default);
        Task<int> CreateUserAsync(string name, string email, CancellationToken ct = default);
    }

    public interface IDriverRepository
    {
        Task<IEnumerable<DriverDto>> GetAllDriversAsync(CancellationToken ct = default);
        Task<int> CreateDriverAsync(int userId, int departmentId, CancellationToken ct = default);
    }

    public interface IVehicleRepository
    {
        Task<IEnumerable<VehicleDto>> GetAllVehiclesAsync(CancellationToken ct = default);
        Task<int> CreateVehicleAsync(int typeId, int statusId, CancellationToken ct = default);
    }

    public interface ITripRepository
    {
        Task<IEnumerable<TripDto>> GetAllTripsAsync(CancellationToken ct = default);
        Task<int> CreateTripAsync(int driverId, int vehicleId, CancellationToken ct = default);
    }

    public class UserRepository : IUserRepository
    {
        private readonly NpgsqlConnection _conn;
        public UserRepository(NpgsqlConnection conn) => _conn = conn;

        public async Task<IEnumerable<UserDto>> GetAllUsersAsync(CancellationToken ct = default)
        {
            var list = new List<UserDto>();
            const string sql = "SELECT id, name, email FROM users WHERE is_deleted = false;";
            using var cmd = new NpgsqlCommand(sql, _conn);
            using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                list.Add(new UserDto
                {
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    Email = reader.GetString(2)
                });
            }
            return list;
        }

        public async Task<int> CreateUserAsync(string name, string email, CancellationToken ct = default)
        {
            const string sql = "SELECT fn_create_user(@name, @email);";
            using var cmd = new NpgsqlCommand(sql, _conn);
            cmd.Parameters.AddWithValue("name", name);
            cmd.Parameters.AddWithValue("email", email);
            var result = await cmd.ExecuteScalarAsync(ct);
            return (int)result!;
        }
    }

    public class DriverRepository : IDriverRepository
    {
        private readonly NpgsqlConnection _conn;
        public DriverRepository(NpgsqlConnection conn) => _conn = conn;

        public async Task<IEnumerable<DriverDto>> GetAllDriversAsync(CancellationToken ct = default)
        {
            var list = new List<DriverDto>();
            const string sql = "SELECT id, user_id, department_id FROM drivers WHERE is_deleted = false;";
            using var cmd = new NpgsqlCommand(sql, _conn);
            using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                list.Add(new DriverDto
                {
                    Id = reader.GetInt32(0),
                    UserId = reader.GetInt32(1),
                    DepartmentId = reader.GetInt32(2)
                });
            }
            return list;
        }

        public async Task<int> CreateDriverAsync(int userId, int departmentId, CancellationToken ct = default)
        {
            const string sql = "SELECT fn_create_driver(@user_id, @department_id);";
            using var cmd = new NpgsqlCommand(sql, _conn);
            cmd.Parameters.AddWithValue("user_id", userId);
            cmd.Parameters.AddWithValue("department_id", departmentId);
            var result = await cmd.ExecuteScalarAsync(ct);
            return (int)result!;
        }
    }

    public class VehicleRepository : IVehicleRepository
    {
        private readonly NpgsqlConnection _conn;
        public VehicleRepository(NpgsqlConnection conn) => _conn = conn;

        public async Task<IEnumerable<VehicleDto>> GetAllVehiclesAsync(CancellationToken ct = default)
        {
            var list = new List<VehicleDto>();
            const string sql = "SELECT id, type_id, status_id FROM vehicles WHERE is_deleted = false;";
            using var cmd = new NpgsqlCommand(sql, _conn);
            using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                list.Add(new VehicleDto
                {
                    Id = reader.GetInt32(0),
                    TypeId = reader.GetInt32(1),
                    StatusId = reader.GetInt32(2)
                });
            }
            return list;
        }

        public async Task<int> CreateVehicleAsync(int typeId, int statusId, CancellationToken ct = default)
        {
            const string sql = "SELECT fn_create_vehicle(@type_id, @status_id);";
            using var cmd = new NpgsqlCommand(sql, _conn);
            cmd.Parameters.AddWithValue("type_id", typeId);
            cmd.Parameters.AddWithValue("status_id", statusId);
            var result = await cmd.ExecuteScalarAsync(ct);
            return (int)result!;
        }
    }

    public class TripRepository : ITripRepository
    {
        private readonly NpgsqlConnection _conn;
        public TripRepository(NpgsqlConnection conn) => _conn = conn;

        public async Task<IEnumerable<TripDto>> GetAllTripsAsync(CancellationToken ct = default)
        {
            var list = new List<TripDto>();
            const string sql = "SELECT id, driver_id, vehicle_id FROM trips;";
            using var cmd = new NpgsqlCommand(sql, _conn);
            using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                list.Add(new TripDto
                {
                    Id = reader.GetInt32(0),
                    DriverId = reader.GetInt32(1),
                    VehicleId = reader.GetInt32(2)
                });
            }
            return list;
        }

        public async Task<int> CreateTripAsync(int driverId, int vehicleId, CancellationToken ct = default)
        {
            const string sql = "SELECT fn_create_trip(@driver_id, @vehicle_id);";
            using var cmd = new NpgsqlCommand(sql, _conn);
            cmd.Parameters.AddWithValue("driver_id", driverId);
            cmd.Parameters.AddWithValue("vehicle_id", vehicleId);
            var result = await cmd.ExecuteScalarAsync(ct);
            return (int)result!;
        }
    }
}
