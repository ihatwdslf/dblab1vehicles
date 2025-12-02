namespace Dblab1Vehicles
{
    public class UserDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = default!;
        public string Email { get; set; } = default!;
    }

    public class DriverDto
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int DepartmentId { get; set; }
    }

    public class VehicleDto
    {
        public int Id { get; set; }
        public int TypeId { get; set; }
        public int StatusId { get; set; }
    }

    public class TripDto
    {
        public int Id { get; set; }
        public int DriverId { get; set; }
        public int VehicleId { get; set; }
    }
}
