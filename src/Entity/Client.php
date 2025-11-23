<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use App\Repository\ClientRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\Put;
use Symfony\Component\Serializer\Annotation\Groups;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity(repositoryClass: ClientRepository::class)]
#[ApiResource(
    order: ['id' => 'ASC'],
    paginationEnabled: false,
    normalizationContext: ['groups' => ['client:read:item']],
    denormalizationContext: ['groups' => ['client:write']],
    operations: [
        new Get(),
        new Post(),
        new Put(),
        new Delete(),
        new GetCollection(normalizationContext: ['groups' => ['client:read:collection']])
    ],
)]
class Client
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['client:read:item', 'client:read:collection', 'order:read:item', 'order:write'])]
    private ?int $id = null;

    #[ORM\Column(length: 255)]
    #[Assert\NotBlank]
    #[Assert\Length(min: 2, max: 255)]
    #[Groups(['client:read:item', 'client:read:collection', 'client:write', 'order:read:item', 'order:read:collection'])]
    private ?string $name = null;

    #[ORM\Column]
    #[Assert\NotBlank]
    #[Assert\Positive]
    #[Groups(['client:read:item', 'client:read:collection', 'client:write', 'order:read:item'])]
    private ?int $phone = null;

    #[ORM\Column(length: 255)]
    #[Assert\NotBlank]
    #[Assert\Email]
    #[Assert\Length(max: 255)]
    #[Groups(['client:read:item', 'client:read:collection', 'client:write', 'order:read:item'])]
    private ?string $email = null;

    #[ORM\Column]
    #[Assert\NotNull]
    #[Assert\PositiveOrZero]
    #[Groups(['client:read:item', 'client:read:collection', 'client:write', 'order:read:item'])]
    private ?int $loyalty_points = 0;

    #[ORM\Column(type: 'datetime_immutable')]
    #[Groups(['client:read:item', 'client:read:collection'])]
    private ?\DateTimeImmutable $createdAt = null;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
        $this->loyalty_points = 0;
    }

    // --- Getters / Setters ---

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

    public function getPhone(): ?int
    {
        return $this->phone;
    }

    public function setPhone(int $phone): static
    {
        $this->phone = $phone;
        return $this;
    }

    public function getEmail(): ?string
    {
        return $this->email;
    }

    public function setEmail(string $email): static
    {
        $this->email = $email;
        return $this;
    }

    public function getLoyaltyPoints(): ?int
    {
        return $this->loyalty_points;
    }

    public function setLoyaltyPoints(int $loyalty_points): static
    {
        $this->loyalty_points = $loyalty_points;
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