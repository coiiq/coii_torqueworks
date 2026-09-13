CREATE TABLE IF NOT EXISTS `coii_torqueworks` (
    `plate` VARCHAR(12) NOT NULL,
    `model` BIGINT UNSIGNED NOT NULL,
    `factory_seed` INT UNSIGNED NOT NULL,
    `build` JSON NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `coii_torqueworks_mmi` (
    `plate` VARCHAR(12) NOT NULL,
    `placement` JSON NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
