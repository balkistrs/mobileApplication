<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use App\Repository\ProductComponentRepository;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Serializer\Annotation\Groups;

#[ORM\Entity(repositoryClass: ProductComponentRepository::class)]
#[ORM\Table(name: 'product_components')]
#[ApiResource(
    normalizationContext: ['groups' => ['product_component:read']],
    denormalizationContext: ['groups' => ['product_component:write']]
)]
class ProductComponent
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'integer')]
    #[Groups(['product_component:read', 'order_item:read', 'order:read'])]
    private ?int $id = null;

    #[ORM\ManyToOne(targetEntity: Product::class, inversedBy: 'components')]
    #[ORM\JoinColumn(nullable: false)]
    #[Groups(['product_component:read', 'product_component:write'])]
    private ?Product $product = null;

    #[ORM\Column(type: 'string', length: 255)]
    #[Groups(['product_component:read', 'product_component:write', 'order_item:read', 'order:read'])]
    private string $name;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)]
    #[Groups(['product_component:read', 'product_component:write', 'order_item:read', 'order:read'])]
    private float $price = 0.0;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['product_component:read', 'product_component:write', 'order_item:read', 'order:read'])]
    private bool $isOptional = false;

    #[ORM\Column(type: 'datetime')]
    #[Groups(['product_component:read'])]
    private \DateTimeInterface $createdAt;

    public function __construct()
    {
        $this->createdAt = new \DateTime();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getProduct(): ?Product
    {
        return $this->product;
    }

    public function setProduct(?Product $product): self
    {
        $this->product = $product;
        return $this;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function setName(string $name): self
    {
        $this->name = $name;
        return $this;
    }

    public function getPrice(): float
    {
        return $this->price;
    }

    public function setPrice(float $price): self
    {
        $this->price = $price;
        return $this;
    }

    public function isOptional(): bool
    {
        return $this->isOptional;
    }

    public function setIsOptional(bool $isOptional): self
    {
        $this->isOptional = $isOptional;
        return $this;
    }

    public function getCreatedAt(): \DateTimeInterface
    {
        return $this->createdAt;
    }

    public function setCreatedAt(\DateTimeInterface $createdAt): self
    {
        $this->createdAt = $createdAt;
        return $this;
    }
}