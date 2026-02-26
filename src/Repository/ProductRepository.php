<?php
// src/Repository/ProductRepository.php

namespace App\Repository;

use App\Entity\Product;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Product>
 */
class ProductRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Product::class);
    }

    /**
     * Find products by category
     * @return Product[]
     */
    public function findByCategory(string $category): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.category = :category')
            ->setParameter('category', $category)
            ->orderBy('p.name', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Find popular products
     * @return Product[]
     */
    public function findPopular(): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.populaire = :popular')
            ->setParameter('popular', true)
            ->orderBy('p.rating', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Search products by name
     * @return Product[]
     */
    public function searchByName(string $searchTerm): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.name LIKE :search')
            ->setParameter('search', '%' . $searchTerm . '%')
            ->orderBy('p.name', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Find available products
     * @return Product[]
     */
    public function findAvailable(): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.isAvailable = :available')
            ->setParameter('available', true)
            ->orderBy('p.name', 'ASC')
            ->getQuery()
            ->getResult();
    }
}