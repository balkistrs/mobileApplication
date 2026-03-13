<?php

namespace App\Repository;

use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;
use Symfony\Component\Security\Core\Exception\UnsupportedUserException;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\PasswordUpgraderInterface;

/**
 * @extends ServiceEntityRepository<User>
 *
 * @method User|null find($id, $lockMode = null, $lockVersion = null)
 * @method User|null findOneBy(array $criteria, array $orderBy = null)
 * @method User[]    findAll()
 * @method User[]    findBy(array $criteria, array $orderBy = null, $limit = null, $offset = null)
 */
class UserRepository extends ServiceEntityRepository implements PasswordUpgraderInterface
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, User::class);
    }

    public function save(User $entity, bool $flush = false): void
    {
        $this->getEntityManager()->persist($entity);

        if ($flush) {
            $this->getEntityManager()->flush();
        }
    }

    public function remove(User $entity, bool $flush = false): void
    {
        $this->getEntityManager()->remove($entity);

        if ($flush) {
            $this->getEntityManager()->flush();
        }
    }

    /**
     * Used to upgrade (rehash) the user's password automatically over time.
     */
    public function upgradePassword(PasswordAuthenticatedUserInterface $user, string $newHashedPassword): void
    {
        if (!$user instanceof User) {
            throw new UnsupportedUserException(sprintf('Instances of "%s" are not supported.', \get_class($user)));
        }

        $user->setPassword($newHashedPassword);
        $this->save($user, true);
    }

    /**
     * Find user by email
     */
    public function findByEmail(string $email): ?User
    {
        return $this->findOneBy(['email' => $email]);
    }

    /**
     * Find users by role
     */
    public function findByRole(string $role): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.roles LIKE :role')
            ->setParameter('role', '%"' . $role . '"%')
            ->orderBy('u.id', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Find users created between two dates
     */
    public function findByDateRange(\DateTimeInterface $startDate, \DateTimeInterface $endDate): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.createdAt BETWEEN :start AND :end')
            ->setParameter('start', $startDate)
            ->setParameter('end', $endDate)
            ->orderBy('u.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Count users by role
     */
    public function countByRole(string $role): int
    {
        return $this->createQueryBuilder('u')
            ->select('COUNT(u.id)')
            ->where('u.roles LIKE :role')
            ->setParameter('role', '%"' . $role . '"%')
            ->getQuery()
            ->getSingleScalarResult();
    }

    /**
     * Get users with pagination
     */
    public function findWithPagination(int $page, int $limit = 10): array
    {
        $offset = ($page - 1) * $limit;
        
        return $this->createQueryBuilder('u')
            ->orderBy('u.id', 'DESC')
            ->setFirstResult($offset)
            ->setMaxResults($limit)
            ->getQuery()
            ->getResult();
    }

    /**
     * Search users by email or name
     */
    public function search(string $query): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.email LIKE :query')
            ->orWhere('u.name LIKE :query')
            ->setParameter('query', '%' . $query . '%')
            ->orderBy('u.id', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Get new users count since a specific date
     */
    public function countNewUsersSince(\DateTimeInterface $date): int
    {
        return $this->createQueryBuilder('u')
            ->select('COUNT(u.id)')
            ->where('u.createdAt >= :date')
            ->setParameter('date', $date)
            ->getQuery()
            ->getSingleScalarResult();
    }

    /**
     * Get users with votes
     */
    public function findUsersWithVote(): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.vote IS NOT NULL')
            ->orderBy('u.vote', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Get average vote
     */
    public function getAverageVote(): float
    {
        $result = $this->createQueryBuilder('u')
            ->select('AVG(u.vote) as avgVote')
            ->where('u.vote IS NOT NULL')
            ->getQuery()
            ->getSingleScalarResult();
            
        return $result ? (float) $result : 0.0;
    }

    /**
     * Get admin users
     */
    public function findAdmins(): array
    {
        return $this->findByRole('ROLE_ADMIN');
    }

    /**
     * Get chef users
     */
    public function findChefs(): array
    {
        return $this->findByRole('ROLE_CHEF');
    }

    /**
     * Get serveur users
     */
    public function findServeurs(): array
    {
        return $this->findByRole('ROLE_SERVEUR');
    }

    /**
     * Get client users
     */
    public function findClients(): array
    {
        return $this->findByRole('ROLE_CLIENT');
    }

    /**
     * Get users with Google auth
     */
    public function findGoogleUsers(): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.googleId IS NOT NULL')
            ->getQuery()
            ->getResult();
    }
}