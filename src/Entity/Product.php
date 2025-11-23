<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Serializer\Annotation\Groups;
use App\Repository\ProductRepository;

#[ORM\Entity(repositoryClass: ProductRepository::class)]
#[ORM\Table(name: 'products')]
#[ApiResource(
    normalizationContext: ['groups' => ['product:read']],
    denormalizationContext: ['groups' => ['product:write']]
)]
class Product
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'integer')]
    #[Groups(['product:read', 'order_item:read', 'order:read'])]
    private ?int $id = null;

    #[ORM\Column(type: 'string', length: 255)]
    #[Groups(['product:read', 'product:write', 'order_item:read', 'order:read'])]
    private string $name;

    #[ORM\Column(type: 'text', nullable: true)]
    #[Groups(['product:read', 'product:write', 'order_item:read', 'order:read'])]
    private ?string $description = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)]
    #[Groups(['product:read', 'product:write', 'order_item:read', 'order:read'])]
    private float $price = 0.0;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['product:read', 'product:write', 'order_item:read', 'order:read'])]
    private bool $isAvailable = true;

    #[ORM\OneToMany(mappedBy: 'product', targetEntity: ProductComponent::class, cascade: ['persist', 'remove'], orphanRemoval: true)]
    #[Groups(['product:read'])]
    private Collection $components;

    #[ORM\Column(type: 'datetime')]
    #[Groups(['product:read'])]
    private \DateTimeInterface $createdAt;

    #[ORM\Column(type: 'datetime', nullable: true)]
    #[Groups(['product:read'])]
    private ?\DateTimeInterface $updatedAt = null;

    public function __construct()
    {
        $this->components = new ArrayCollection();
        $this->createdAt = new \DateTime();
    }

    public function getId(): ?int
    {
        return $this->id;
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

    public function getDescription(): ?string
    {
        return $this->description;
    }

    public function setDescription(?string $description): self
    {
        $this->description = $description;
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

    public function isAvailable(): bool
    {
        return $this->isAvailable;
    }

    public function setIsAvailable(bool $isAvailable): self
    {
        $this->isAvailable = $isAvailable;
        return $this;
    }

    /**
     * @return Collection<int, ProductComponent>
     */
    public function getComponents(): Collection
    {
        return $this->components;
    }

    public function addComponent(ProductComponent $component): self
    {
        if (!$this->components->contains($component)) {
            $this->components[] = $component;
            $component->setProduct($this);
        }

        return $this;
    }

    public function removeComponent(ProductComponent $component): self
    {
        if ($this->components->removeElement($component)) {
            if ($component->getProduct() === $this) {
                $component->setProduct(null);
            }
        }

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

    public function getUpdatedAt(): ?\DateTimeInterface
    {
        return $this->updatedAt;
    }

    public function setUpdatedAt(?\DateTimeInterface $updatedAt): self
    {
        $this->updatedAt = $updatedAt;
        return $this;
    }
}