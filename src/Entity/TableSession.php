<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use App\Repository\TableSessionRepository;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Serializer\Annotation\Groups;

#[ORM\Entity(repositoryClass: TableSessionRepository::class)]
#[ORM\Table(name: 'table_sessions')]
#[ApiResource(
    normalizationContext: ['groups' => ['table_session:read']],
    denormalizationContext: ['groups' => ['table_session:write']]
)]
class TableSession
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'integer')]
    #[Groups(['table_session:read', 'table:read:item', 'table:read:collection'])]
    private ?int $id = null;

    #[ORM\ManyToOne(targetEntity: Table::class, inversedBy: 'tableSessions')]
    #[ORM\JoinColumn(nullable: false)]
    #[Groups(['table_session:read', 'table_session:write'])]
    private ?Table $table = null;

    #[ORM\ManyToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false)]
    #[Groups(['table_session:read', 'table_session:write'])]
    private ?User $user = null;

    #[ORM\Column(type: 'datetime')]
    #[Groups(['table_session:read', 'table_session:write', 'table:read:item', 'table:read:collection'])]
    private \DateTimeInterface $startTime;

    #[ORM\Column(type: 'datetime', nullable: true)]
    #[Groups(['table_session:read', 'table_session:write', 'table:read:item', 'table:read:collection'])]
    private ?\DateTimeInterface $endTime = null;

    #[ORM\Column(type: 'string', length: 50)]
    #[Groups(['table_session:read', 'table_session:write', 'table:read:item', 'table:read:collection'])]
    private string $status = 'active';

    public function __construct()
    {
        $this->startTime = new \DateTime();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getTable(): ?Table
    {
        return $this->table;
    }

    public function setTable(?Table $table): self
    {
        $this->table = $table;
        return $this;
    }

    public function getUser(): ?User
    {
        return $this->user;
    }

    public function setUser(?User $user): self
    {
        $this->user = $user;
        return $this;
    }

    public function getStartTime(): \DateTimeInterface
    {
        return $this->startTime;
    }

    public function setStartTime(\DateTimeInterface $startTime): self
    {
        $this->startTime = $startTime;
        return $this;
    }

    public function getEndTime(): ?\DateTimeInterface
    {
        return $this->endTime;
    }

    public function setEndTime(?\DateTimeInterface $endTime): self
    {
        $this->endTime = $endTime;
        return $this;
    }

    public function getStatus(): string
    {
        return $this->status;
    }

    public function setStatus(string $status): self
    {
        $this->status = $status;
        return $this;
    }
}