<?php

namespace App\Repository;

use App\Entity\Payment;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Payment>
 *
 * @method Payment|null find($id, $lockMode = null, $lockVersion = null)
 * @method Payment|null findOneBy(array $criteria, array $orderBy = null)
 * @method Payment[]    findAll()
 * @method Payment[]    findBy(array $criteria, array $orderBy = null, $limit = null, $offset = null)
 */
class PaymentRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Payment::class);
    }

    public function save(Payment $entity, bool $flush = false): void
    {
        $this->getEntityManager()->persist($entity);

        if ($flush) {
            $this->getEntityManager()->flush();
        }
    }

    public function remove(Payment $entity, bool $flush = false): void
    {
        $this->getEntityManager()->remove($entity);

        if ($flush) {
            $this->getEntityManager()->flush();
        }
    }

    /**
     * Trouver les paiements par commande
     * @return Payment[]
     */
    public function findByOrderId(int $orderId): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.orderId = :orderId')
            ->setParameter('orderId', $orderId)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouver les paiements par client
     * @return Payment[]
     */
    public function findByClientId(int $clientId): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.clientId = :clientId')
            ->setParameter('clientId', $clientId)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouver les paiements par méthode
     * @return Payment[]
     */
    public function findByMethod(string $method): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.method = :method')
            ->setParameter('method', $method)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }
}