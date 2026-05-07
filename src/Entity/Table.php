<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use App\Repository\TableRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\Put;
use Symfony\Component\Serializer\Annotation\Groups;

#[ORM\Entity(repositoryClass: TableRepository::class)]
#[ORM\Table(name: '`table`')]
#[ApiResource(
    order: ['id' => 'ASC'],
    paginationEnabled: false,
    normalizationContext: ['groups' => ['table:read:item']],
    denormalizationContext: ['groups' => ['table:write']],
    operations: [
        new Get(),
        new Post(),
        new Put(),
        new Delete(),
        new GetCollection(normalizationContext: ['groups' => ['table:read:collection']])
    ],
)]
class Table
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['table:read:item', 'table:read:collection'])]
    private ?int $id = null;

    #[ORM\Column(length: 255)]
    #[Groups(['table:read:item', 'table:read:collection', 'table:write'])]
    private ?string $name = null;

    #[ORM\Column]
    #[Groups(['table:read:item', 'table:read:collection', 'table:write'])]
    private ?int $capacity = null;

    #[ORM\Column]
    #[Groups(['table:read:item', 'table:read:collection', 'table:write'])]
    private ?bool $isAvailable = null;

    #[ORM\Column]
    #[Groups(['table:read:item', 'table:read:collection', 'table:write'])]
    private ?int $positionX = null;

    #[ORM\Column]
    #[Groups(['table:read:item', 'table:read:collection', 'table:write'])]
    private ?int $positionY = null;

    #[ORM\OneToMany(mappedBy: 'table', targetEntity: TableSession::class, cascade: ['persist', 'remove'])]
    #[Groups(['table:read:item', 'table:read:collection'])]
    private Collection $tableSessions;

    #[ORM\Column(type: 'datetime_immutable')]
    #[Groups(['table:read:item', 'table:read:collection'])]
    private ?\DateTimeImmutable $createdAt = null;

    public function __construct()
    {
        $this->tableSessions = new ArrayCollection();
        $this->createdAt = new \DateTimeImmutable();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getName(): ?string
    {
        return $this->name;
    }

    public function setName(string $name): static
    {
        $this->name = $name;
        return $this;
    }

    public function getCapacity(): ?int
    {
        return $this->capacity;
    }

    public function setCapacity(int $capacity): static
    {
        $this->capacity = $capacity;
        return $this;
    }

    public function isAvailable(): ?bool
    {
        return $this->isAvailable;
    }

    public function setIsAvailable(bool $isAvailable): static
    {
        $this->isAvailable = $isAvailable;
        return $this;
    }

    public function getPositionX(): ?int
    {
        return $this->positionX;
    }

    public function setPositionX(int $positionX): static
    {
        $this->positionX = $positionX;
        return $this;
    }

    public function getPositionY(): ?int
    {
        return $this->positionY;
    }

    public function setPositionY(int $positionY): static
    {
        $this->positionY = $positionY;
        return $this;
    }

    /**
     * @return Collection<int, TableSession>
     */
    public function getTableSessions(): Collection
    {
        return $this->tableSessions;
    }

    public function addTableSession(TableSession $tableSession): static
    {
        if (!$this->tableSessions->contains($tableSession)) {
            $this->tableSessions->add($tableSession);
            $tableSession->setTable($this);
        }
        return $this;
    }

    public function removeTableSession(TableSession $tableSession): static
        {
            if ($this->tableSessions->removeElement($tableSession)) {
                if ($tableSession->getTable() === $this) {
                    $tableSession->setTable(null);
                }
            }
            return $this;
        }

    public function getCreatedAt(): ?\DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function setCreatedAt(\DateTimeImmutable $createdAt): static
    {
        $this->createdAt = $createdAt;
        return $this;
    }
}