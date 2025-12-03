# Система управління автопарком (Vehicles Management System)

## 1. Загальна інформація

**Мета проєкту:**  
Створити інформаційну систему для управління автопарком, а саме: транспортними засобами, водіями та поїздками, де всі операції з БД виконуються через збережені процедури та представлені через Repository + Unit of Work.

**Основні задачі системи:**

- облік користувачів та їх ролей;
- облік водіїв і прив'язка до користувачів та підрозділів;
- облік транспортних засобів та їх статусів;
- облік поїздок з прив'язкою до водіїв та транспортних засобів;
- використання soft delete для ключових сутностей;
- ведення аудиту змін;
- робота з БД виключно через збережені функції та процедури.

**Технології:**

- **СУБД:** PostgreSQL  
- **Клієнт до БД:** Npgsql (ADO.NET)  
- **Архітектура застосунку:** C# Console App + Repository + Unit of Work  
- **Мова програмування:** C# (.NET 8)  
- **Інші інструменти:**  
  - pgAdmin — адміністрування БД
  - dbdiagram.io — ER-діаграма
  - GitHub — зберігання коду та SQL-скриптів  


## 2. Структура бази даних

**Кількість сутностей:** 17

### Основні таблиці:

#### Користувачі та водії
- **users** – користувачі системи (адміністратори, менеджери, водії)
- **drivers** – водії автопарку (один користувач може бути водієм)
- **license_categories** – категорії водійських посвідчень (A, B, C, D)
- **driver_license_categories** – зв'язок водіїв та їх категорій (M:M)

#### Організаційна структура
- **departments** – відділи підприємства

#### Транспортні засоби
- **vehicles** – транспортні засоби автопарку
- **vehicle_types** – типи транспорту (Car, Truck, Van, Bus)
- **vehicle_status** – статуси транспорту (available, in use, maintenance)
- **vehicle_documents** – документи транспортних засобів
- **insurance_policies** – страхові поліси

#### Поїздки та маршрути
- **routes** – маршрути пересування
- **trips** – поїздки транспорту з водіями

#### Обслуговування
- **maintenance_records** – записи про технічне обслуговування
- **maintenance_types** – типи обслуговування (Oil Change, Tire Change, Inspection)
- **service_providers** – постачальники послуг обслуговування

#### Паливо
- **fuel_records** – записи про заправки

#### Аудит
- **audit_log** – централізований журнал всіх змін у системі

---

### Основні зв'язки між сутностями

#### Користувачі та водії
- `users` **1:1** `drivers` (користувач може бути водієм, необов'язково)
  - `drivers.user_id → users.id` (UNIQUE)
- `users` **1:M** `maintenance_records` (користувач реєструє обслуговування)
  - `maintenance_records.user_id → users.id`
- `users` **1:M** `fuel_records` (користувач реєструє заправки)
  - `fuel_records.user_id → users.id`
- `users` **1:M** `audit_log` (користувач виконує дії в системі)
  - `audit_log.user_id → users.id`

#### Водії та категорії (Many-to-Many)
- `drivers` **M:M** `license_categories` через `driver_license_categories`
  - `driver_license_categories.driver_id → drivers.id`
  - `driver_license_categories.category_id → license_categories.id`

#### Організаційна структура
- `departments` **1:M** `drivers` (відділ має водіїв)
  - `drivers.department_id → departments.id`
- `departments` **1:M** `vehicles` (відділ має транспорт)
  - `vehicles.department_id → departments.id`

#### Транспортні засоби та класифікація
- `vehicle_types` **1:M** `vehicles` (тип присвоюється транспорту)
  - `vehicles.type_id → vehicle_types.id`
- `vehicle_status` **1:M** `vehicles` (статус присвоюється транспорту)
  - `vehicles.status_id → vehicle_status.id`

#### Транспорт та документація
- `vehicles` **1:M** `vehicle_documents` (транспорт має документи)
  - `vehicle_documents.vehicle_id → vehicles.id`
- `vehicles` **1:M** `insurance_policies` (транспорт має страховки)
  - `insurance_policies.vehicle_id → vehicles.id`

#### Поїздки
- `drivers` **1:M** `trips` (водій здійснює поїздки)
  - `trips.driver_id → drivers.id`
- `vehicles` **1:M** `trips` (транспорт використовується в поїздках)
  - `trips.vehicle_id → vehicles.id`
- `routes` **1:M** `trips` (маршрут використовується в поїздках)
  - `trips.route_id → routes.id`

#### Обслуговування
- `vehicles` **1:M** `maintenance_records` (транспорт проходить обслуговування)
  - `maintenance_records.vehicle_id → vehicles.id`
- `maintenance_types` **1:M** `maintenance_records` (тип обслуговування)
  - `maintenance_records.maintenance_type_id → maintenance_types.id`
- `service_providers` **1:M** `maintenance_records` (постачальник виконує роботи)
  - `maintenance_records.service_provider_id → service_providers.id`

#### Паливо
- `vehicles` **1:M** `fuel_records` (транспорт заправляється)
  - `fuel_records.vehicle_id → vehicles.id`

#### Аудит змін (updated_by)
- `users.updated_by → users.id` (самопосилання)
- `drivers.updated_by → users.id`
- `vehicles.updated_by → users.id`
- `routes.updated_by → users.id`
- `vehicle_documents.updated_by → users.id`

---

### Ключі

#### Первинні ключі:
- Автоінкрементні `id` у всіх основних таблицях:
  - `users`, `drivers`, `vehicles`, `trips`, `routes`, `maintenance_records`, `fuel_records`, `vehicle_documents`, `insurance_policies`, `departments`, `vehicle_types`, `vehicle_status`, `maintenance_types`, `service_providers`, `license_categories`, `audit_log`
- Складені PK у таблиці-зв'язку:
  - `driver_license_categories(id)` – первинний ключ, але з унікальним індексом на `(driver_id, category_id)`

#### Зовнішні ключі:
Усі зв'язки між таблицями реалізовані через foreign keys з відповідними обмеженнями:
- `ON DELETE CASCADE` – для залежних даних (коментарі, документи)
- `ON DELETE SET NULL` – для необов'язкових зв'язків
- `ON DELETE RESTRICT` – для критичних зв'язків (користувачі, транспорт)

---

## 3. Вимоги до даних

### Soft delete

Реалізовано "м'яке видалення" (soft delete) для критичних сутностей:

**Таблиці з полями soft delete:**
- `users`
- `drivers`
- `vehicles`
- `routes`
- `vehicle_documents`

**Поля:**
- `is_deleted` (boolean, default: false)
- `created_at` (timestamp)

**Механізм:**
При оновленні поля `is_deleted` на `true`, тригер `trg_vehicles_soft_delete` автоматично:
- Встановлює `updated_at = NOW()`
- Додає запис до `audit_log` про м'яке видалення

**Приклад тригерної функції:**
```sql
CREATE FUNCTION fn_vehicles_soft_delete_trigger() RETURNS trigger AS $$
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        NEW.updated_at := NOW();
        INSERT INTO audit_log (user_id, action, created_at)
        VALUES (NEW.updated_by, 
                'Vehicle ' || NEW.id || ' soft-deleted', 
                NOW());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

### Аудит змін

Використовуються стандартні поля аудиту для відстеження історії змін:

**Поля:**
- `created_at` (timestamp) – дата створення запису
- `updated_at` (timestamp) – дата останньої зміни
- `updated_by` (integer) – користувач, який останнім змінював запис

**Таблиці з аудитом:**
- `users`
- `drivers`
- `vehicles`
- `routes`
- `vehicle_documents`

**Механізм:**
При кожному `UPDATE` на таблицях, тригер `trg_users_update` автоматично оновлює поля `updated_at` та `updated_by`.

**Приклад тригерної функції:**
```sql
CREATE FUNCTION fn_users_update_trigger() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.updated_by = NEW.id;  -- Встановлюємо поточного користувача
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

### Централізований журнал аудиту

Таблиця **`audit_log`** зберігає історію всіх критичних операцій у системі:

**Структура:**
```sql
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Типи дій, що логуються:**
- Soft delete транспортних засобів
- Зміна статусів транспорту при поїздках
- Критичні операції користувачів

**Приклад запису:**
```
id: 1
user_id: 1
action: "Vehicle 1 soft-deleted"
created_at: 2025-12-02 01:20:16
```

---

## 4. Реалізація у PostgreSQL

### Тригерні функції

#### 1. `fn_users_update_trigger()`
Автоматично оновлює `updated_at` та `updated_by` при зміні користувача.
```sql
CREATE FUNCTION fn_users_update_trigger() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.updated_by = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Застосування:**
```sql
CREATE TRIGGER trg_users_update
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION fn_users_update_trigger();
```

---

#### 2. `fn_vehicles_soft_delete_trigger()`
Перехоплює м'яке видалення транспорту та логує подію в `audit_log`.
```sql
CREATE FUNCTION fn_vehicles_soft_delete_trigger() RETURNS trigger AS $$
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        NEW.updated_at := NOW();
        INSERT INTO audit_log (user_id, action, created_at)
        VALUES (NEW.updated_by, 
                'Vehicle ' || NEW.id || ' soft-deleted', 
                NOW());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Застосування:**
```sql
CREATE TRIGGER trg_vehicles_soft_delete
    BEFORE UPDATE ON vehicles
    FOR EACH ROW
    EXECUTE FUNCTION fn_vehicles_soft_delete_trigger();
```

---

#### 3. `fn_trips_insert_trigger()`
Автоматично змінює статус транспорту на "in use" при створенні нової поїздки.
```sql
CREATE FUNCTION fn_trips_insert_trigger() RETURNS trigger AS $$
BEGIN
    -- Перевіряємо статус машини
    IF (SELECT status_id FROM vehicles WHERE id = NEW.vehicle_id) <> 1 THEN
        RAISE EXCEPTION 'Vehicle is not available for a new trip';
    END IF;

    -- Міняємо статус на in_use
    UPDATE vehicles
    SET status_id = 2
    WHERE id = NEW.vehicle_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Застосування:**
```sql
CREATE TRIGGER trg_trips_insert
    BEFORE INSERT ON trips
    FOR EACH ROW
    EXECUTE FUNCTION fn_trips_insert_trigger();
```

---

### Тригери

Активні тригери в системі:

| Тригер | Таблиця | Подія | Функція | Призначення |
|--------|---------|-------|---------|-------------|
| `trg_users_update` | `users` | BEFORE UPDATE | `fn_users_update_trigger()` | Оновлення аудит-полів |
| `trg_vehicles_soft_delete` | `vehicles` | BEFORE UPDATE | `fn_vehicles_soft_delete_trigger()` | Логування м'якого видалення |
| `trg_trips_insert` | `trips` | BEFORE INSERT | `fn_trips_insert_trigger()` | Зміна статусу транспорту |

---

### Збережені функції (Stored Functions)

#### 1. `get_driver_trip_count(p_driver_id INTEGER)`
Повертає кількість поїздок конкретного водія.
```sql
CREATE FUNCTION get_driver_trip_count(p_driver_id integer) 
RETURNS integer AS $$
DECLARE
    trip_count integer;
BEGIN
    SELECT COUNT(*) INTO trip_count
    FROM trips
    WHERE driver_id = p_driver_id;

    RETURN trip_count;
END;
$$ LANGUAGE plpgsql;
```

**Використання:**
```sql
SELECT get_driver_trip_count(1);  -- Повертає кількість поїздок водія з ID 1
```

---

#### 2. `get_vehicle_total_fuel(p_vehicle_id INTEGER)`
Повертає загальну кількість палива, заправленого в конкретний транспорт.
```sql
CREATE FUNCTION get_vehicle_total_fuel(p_vehicle_id integer) 
RETURNS numeric AS $$
DECLARE
    total_fuel numeric;
BEGIN
    SELECT COALESCE(SUM(liters), 0) INTO total_fuel
    FROM fuel_records
    WHERE vehicle_id = p_vehicle_id;

    RETURN total_fuel;
END;
$$ LANGUAGE plpgsql;
```

**Використання:**
```sql
SELECT get_vehicle_total_fuel(1);  -- Повертає загальну кількість літрів для транспорту ID 1
```

---

#### 3. `get_active_drivers_by_department(p_department_id INTEGER)`
Повертає список активних водіїв у конкретному відділі.
```sql
CREATE FUNCTION get_active_drivers_by_department(p_department_id integer) 
RETURNS TABLE(driver_id integer, driver_name varchar) AS $$
BEGIN
    RETURN QUERY
    SELECT d.id, u.name
    FROM drivers d
    JOIN users u ON d.user_id = u.id
    WHERE d.is_deleted = false
      AND d.department_id = p_department_id;
END;
$$ LANGUAGE plpgsql;
```

**Використання:**
```sql
SELECT * FROM get_active_drivers_by_department(1);
-- Повертає таблицю з колонками: driver_id, driver_name
```

---

### Представлення (Views)

#### 1. `active_vehicles`
Показує доступний транспорт зі статусом "available".
```sql
CREATE VIEW active_vehicles AS
SELECT 
    v.id AS vehicle_id,
    vt.name AS vehicle_type,
    vs.name AS vehicle_status,
    d.name AS department_name
FROM vehicles v
JOIN vehicle_types vt ON v.type_id = vt.id
JOIN vehicle_status vs ON v.status_id = vs.id
JOIN departments d ON v.department_id = d.id
WHERE v.is_deleted = false 
  AND vs.name = 'available';
```

**Використання:**
```sql
SELECT * FROM active_vehicles;
```

**Результат:**
```
vehicle_id | vehicle_type | vehicle_status | department_name
-----------|--------------|----------------|----------------
1          | Test type1   | available      | Test department1
```

---

#### 2. `driver_license_overview`
Огляд водіїв з їх категоріями посвідчень.
```sql
CREATE VIEW driver_license_overview AS
SELECT 
    u.id AS driver_id,
    u.name AS driver_name,
    STRING_AGG(lc.code, ', ') AS license_categories
FROM drivers d
JOIN users u ON d.user_id = u.id
JOIN driver_license_categories dlc ON dlc.driver_id = d.id
JOIN license_categories lc ON dlc.category_id = lc.id
WHERE d.is_deleted = false
GROUP BY u.id, u.name;
```

**Використання:**
```sql
SELECT * FROM driver_license_overview;
```

**Результат:**
```
driver_id | driver_name | license_categories
----------|-------------|-------------------
1         | Test User1  | A, B, C
2         | Test User2  | B
```

---

#### 3. `recent_trips`
Поїздки за останні 30 днів.
```sql
CREATE VIEW recent_trips AS
SELECT 
    t.id AS trip_id,
    d.name AS driver_name,
    v.id AS vehicle_id,
    r.name AS route_name,
    t.start_time,
    t.end_time
FROM trips t
JOIN drivers dr ON t.driver_id = dr.id
JOIN users d ON dr.user_id = d.id
JOIN vehicles v ON t.vehicle_id = v.id
JOIN routes r ON t.route_id = r.id
WHERE t.start_time >= NOW() - INTERVAL '30 days';
```

**Використання:**
```sql
SELECT * FROM recent_trips;
```

---

#### 4. `maintenance_due`
Транспорт, що потребує обслуговування (останнє обслуговування було більше 6 місяців тому або взагалі не було).
```sql
CREATE VIEW maintenance_due AS
SELECT 
    v.id AS vehicle_id,
    v.type_id,
    v.status_id,
    v.department_id,
    MAX(m.performed_at) AS last_maintenance_date
FROM vehicles v
LEFT JOIN maintenance_records m ON v.id = m.vehicle_id
GROUP BY v.id, v.type_id, v.status_id, v.department_id
HAVING MAX(m.performed_at) IS NULL 
    OR MAX(m.performed_at) < NOW() - INTERVAL '6 months';
```

**Використання:**
```sql
SELECT * FROM maintenance_due;
```

---

### Індекси

**Типи індексів (мінімум 2 різні):**

#### 1. B-Tree (за замовчуванням)
Використовується для швидкого пошуку та сортування.
```sql
CREATE INDEX idx_users_email 
    ON users USING BTREE(email);
```

**Призначення:**
- Швидкий пошук користувачів за email
- Підтримка унікальності (якщо додати UNIQUE)
- Ефективне сортування у запитах

**Приклад використання:**
```sql
SELECT * FROM users WHERE email = 'test1@example.com';
-- Використає idx_users_email для швидкого пошуку
```

---

#### 2. GIN (Generalized Inverted Index)
Використовується для повнотекстового пошуку.
```sql
CREATE INDEX idx_maintenance_types_name_gin 
    ON maintenance_types 
    USING GIN(to_tsvector('english', name));
```

**Призначення:**
- Повнотекстовий пошук по назвах типів обслуговування
- Підтримка складних текстових запитів
- Ефективна робота з великими обсягами тексту

**Приклад використання:**
```sql
SELECT * FROM maintenance_types
WHERE to_tsvector('english', name) @@ plainto_tsquery('english', 'oil change');
-- Використає idx_maintenance_types_name_gin для швидкого повнотекстового пошуку
```

---

### Інші індекси
```sql
-- Унікальний індекс для запобігання дублікатів категорій водія
CREATE UNIQUE INDEX idx_driver_license_unique
    ON driver_license_categories(driver_id, category_id);

-- Індекс для швидкого пошуку поїздок за водієм
CREATE INDEX idx_trips_driver
    ON trips(driver_id);

-- Індекс для швидкого пошуку поїздок за транспортом
CREATE INDEX idx_trips_vehicle
    ON trips(vehicle_id);

-- Індекс для фільтрації активних записів
CREATE INDEX idx_vehicles_not_deleted
    ON vehicles(id) WHERE is_deleted = false;
```

---

## 5. Приклади використання

### Створення нового користувача
```sql
INSERT INTO users (name, email, is_deleted, created_at)
VALUES ('John Doe', 'john@example.com', false, NOW());
```

### Призначення водія до відділу
```sql
INSERT INTO drivers (user_id, department_id, is_deleted, created_at)
VALUES (1, 1, false, NOW());
```

### Додавання категорії водію
```sql
INSERT INTO driver_license_categories (driver_id, category_id)
VALUES (1, 2);  -- Додає категорію B водію з ID 1
```

### Створення нової поїздки
```sql
INSERT INTO trips (driver_id, vehicle_id, route_id, start_time, end_time)
VALUES (1, 1, 1, NOW(), NOW() + INTERVAL '2 hours');
-- Автоматично спрацює тригер trg_trips_insert та змінить статус транспорту
```

### Реєстрація заправки
```sql
INSERT INTO fuel_records (vehicle_id, user_id, liters, price, created_at)
VALUES (1, 1, 50.00, 1800.00, NOW());
```

### М'яке видалення транспорту
```sql
UPDATE vehicles 
SET is_deleted = true, updated_by = 1 
WHERE id = 1;
-- Автоматично спрацює тригер та додасть запис до audit_log
```

### Перегляд статистики водія
```sql
SELECT 
    u.name,
    get_driver_trip_count(d.id) AS total_trips
FROM drivers d
JOIN users u ON d.user_id = u.id
WHERE d.id = 1;
```

### Перегляд витрат палива транспорту
```sql
SELECT 
    v.id,
    get_vehicle_total_fuel(v.id) AS total_fuel_liters
FROM vehicles v
WHERE v.id = 1;
```

---

