<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Make name column nullable in users table
 */
final class Version20260223160000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Make name column nullable in users table';
    }

    public function up(Schema $schema): void
    {
        $this->addSql("ALTER TABLE users MODIFY COLUMN name VARCHAR(255) DEFAULT NULL");
    }

    public function down(Schema $schema): void
    {
        $this->addSql("ALTER TABLE users MODIFY COLUMN name VARCHAR(255) NOT NULL");
    }
}
