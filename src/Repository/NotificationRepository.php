<?php

namespace App\Repository;

use App\Entity\Notification;
use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Notification>
 */
class NotificationRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Notification::class);
    }

  // Dans App\Repository\NotificationRepository.php
public function findByUser(User $user, int $limit = 100): array
{
    return $this->createQueryBuilder('n')
        ->andWhere('n.user = :user')
        ->setParameter('user', $user)
        ->orderBy('n.createdAt', 'DESC')
        ->setMaxResults($limit)
        ->getQuery()
        ->getResult();
}
    public function findUnreadByUser(User $user): array
    {
        return $this->createQueryBuilder('n')
            ->andWhere('n.user = :user')
            ->andWhere('n.isRead = false')
            ->setParameter('user', $user)
            ->orderBy('n.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }
}
