local tables = {
    coii_torqueworks = [[
        CREATE TABLE IF NOT EXISTS `coii_torqueworks` (
            `plate` VARCHAR(12) NOT NULL,
            `model` BIGINT UNSIGNED NOT NULL,
            `factory_seed` INT UNSIGNED NOT NULL,
            `build` JSON NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    coii_torqueworks_dyno_runs = [[
        CREATE TABLE IF NOT EXISTS `coii_torqueworks_dyno_runs` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `plate` VARCHAR(12) NOT NULL,
            `build` JSON NOT NULL,
            `peak_power` DECIMAL(10,2) NOT NULL,
            `peak_torque` DECIMAL(10,2) NOT NULL,
            `samples` JSON NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_coii_torqueworks_dyno_plate` (`plate`, `id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    coii_torqueworks_mmi = [[
        CREATE TABLE IF NOT EXISTS `coii_torqueworks_mmi` (
            `plate` VARCHAR(12) NOT NULL,
            `placement` JSON NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    coii_torqueworks_work_orders = [[
        CREATE TABLE IF NOT EXISTS `coii_torqueworks_work_orders` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `plate` VARCHAR(12) NULL,
            `mechanic_identifier` VARCHAR(80) NOT NULL,
            `customer_identifier` VARCHAR(80) NOT NULL,
            `quote` JSON NOT NULL,
            `total` INT UNSIGNED NOT NULL,
            `payment_method` ENUM('cash', 'bank') NULL,
            `reserved_amount` INT UNSIGNED NOT NULL DEFAULT 0,
            `simulated` TINYINT(1) UNSIGNED NOT NULL DEFAULT 1,
            `status` ENUM('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
            `approval_token` VARCHAR(64) NOT NULL,
            `expires_at` TIMESTAMP NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_coii_torqueworks_work_order_token` (`approval_token`),
            KEY `idx_coii_torqueworks_work_order_customer` (`customer_identifier`, `status`),
            KEY `idx_coii_torqueworks_work_order_mechanic` (`mechanic_identifier`, `status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
}

MySQL.ready(function()
    local ok, message = pcall(function()
        local existingRows = MySQL.query.await([[
            SELECT TABLE_NAME AS name
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME IN ('coii_torqueworks', 'coii_torqueworks_dyno_runs',
                                 'coii_torqueworks_mmi', 'coii_torqueworks_work_orders')
        ]]) or {}
        local existing = {}
        for _, row in ipairs(existingRows) do existing[row.name] = true end

        local created = 0
        for name, statement in pairs(tables) do
            MySQL.query.await(statement)
            if not existing[name] then created = created + 1 end
        end

        if created > 0 then
            print(('^5[coii_torqueworks]^7 Database installed automatically - ^5%d^7 table%s created.'):format(
                created, created == 1 and '' or 's'))
        end
    end)
    if not ok then
        print(('^1[coii_torqueworks] Automatic database installation failed:^7 %s'):format(message))
    end
end)
