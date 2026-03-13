<?php

namespace App\Repository;

use App\Entity\Order;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Order>
 *
 * @method Order|null find($id, $lockMode = null, $lockVersion = null)
 * @method Order|null findOneBy(array $criteria, array $orderBy = null)
 * @method Order[]    findAll()
 * @method Order[]    findBy(array $criteria, array $orderBy = null, $limit = null, $offset = null)
 */
class OrderRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Order::class);
    }

    public function save(Order $entity, bool $flush = false): void
    {
        $this->getEntityManager()->persist($entity);

        if ($flush) {
            $this->getEntityManager()->flush();
        }
    }

    public function remove(Order $entity, bool $flush = false): void
    {
        $this->getEntityManager()->remove($entity);

        if ($flush) {
            $this->getEntityManager()->flush();
        }
    }

    /**
     * Find orders by user
     * @return Order[]
     */
    public function findByUser($user): array
    {
        return $this->createQueryBuilder('o')
            ->where('o.user = :user')
            ->setParameter('user', $user)
            ->orderBy('o.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Find orders by status
     * @return Order[]
     */
    public function findByStatus(string $status): array
    {
        return $this->createQueryBuilder('o')
            ->where('o.status = :status')
            ->setParameter('status', $status)
            ->orderBy('o.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Find orders ready for delivery
     * @return Order[]
     */
    public function findReadyOrders(): array
    {
        return $this->createQueryBuilder('o')
            ->where('o.status = :ready')
            ->orWhere('o.status = :prete')
            ->orWhere('o.status = :completed')
            ->setParameter('ready', 'ready')
            ->setParameter('prete', 'prête')
            ->setParameter('completed', 'completed')
            ->orderBy('o.updatedAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Find all orders with details (user, items, products)
     * @return Order[]
     */
    public function findAllWithDetails(): array
    {
        return $this->createQueryBuilder('o')
            ->leftJoin('o.user', 'u')
            ->leftJoin('o.orderItems', 'oi')
            ->leftJoin('oi.product', 'p')
            ->addSelect('u', 'oi', 'p')
            ->orderBy('o.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Find pending orders
     * @return Order[]
     */
    public function findPendingOrders(): array
    {
        return $this->createQueryBuilder('o')
            ->where('o.status = :pending')
            ->orWhere('o.status = :paid')
            ->setParameter('pending', 'pending')
            ->setParameter('paid', 'paid')
            ->orderBy('o.createdAt', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Get orders statistics by status
     * @return array<string, int>
     */
    public function getStatsByStatus(): array
    {
        $results = $this->createQueryBuilder('o')
            ->select('o.status, COUNT(o.id) as count')
            ->groupBy('o.status')
            ->getQuery()
            ->getResult();
        
        $stats = [];
        foreach ($results as $row) {
            $stats[$row['status']] = (int)$row['count'];
        }
        
        return $stats;
    }

    /**
     * Get total revenue for a period
     */
    public function getTotalRevenue(\DateTimeInterface $startDate, \DateTimeInterface $endDate): float
    {
        $result = $this->createQueryBuilder('o')
            ->select('SUM(o.total) as total')
            ->where('o.createdAt BETWEEN :start AND :end')
            ->andWhere('o.status IN (:statuses)')
            ->setParameter('start', $startDate)
            ->setParameter('end', $endDate)
            ->setParameter('statuses', ['paid', 'completed', 'delivered'])
            ->getQuery()
            ->getSingleScalarResult();
            
        return $result ? (float) $result : 0.0;
    }

    /**
     * Get daily revenue for the last N days
     * @return array<int, array{date: string, revenue: float, order_count: int}>
     */
    public function getDailyRevenue(int $days = 30): array
    {
        $endDate = new \DateTime();
        $startDate = (new \DateTime())->modify("-$days days");

        $results = $this->createQueryBuilder('o')
            ->select('DATE(o.createdAt) as date, SUM(o.total) as revenue, COUNT(o.id) as order_count')
            ->where('o.createdAt BETWEEN :start AND :end')
            ->andWhere('o.status IN (:statuses)')
            ->setParameter('start', $startDate)
            ->setParameter('end', $endDate)
            ->setParameter('statuses', ['paid', 'completed', 'delivered'])
            ->groupBy('date')
            ->orderBy('date', 'ASC')
            ->getQuery()
            ->getResult();

        $dailyStats = [];
        for ($i = 0; $i <= $days; $i++) {
            $date = (clone $startDate)->modify("+$i days")->format('Y-m-d');
            $dailyStats[$date] = [
                'date' => $date,
                'revenue' => 0,
                'order_count' => 0
            ];
        }

        foreach ($results as $row) {
            if (isset($dailyStats[$row['date']])) {
                $dailyStats[$row['date']]['revenue'] = (float) $row['revenue'];
                $dailyStats[$row['date']]['order_count'] = (int) $row['order_count'];
            }
        }

        return array_values($dailyStats);
    }
}