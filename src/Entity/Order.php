<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;
use App\Repository\OrderRepository;
use Symfony\Component\Serializer\Annotation\Groups;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity(repositoryClass: OrderRepository::class)]
#[ORM\Table(name: '`order`', indexes: [
    new ORM\Index(name: 'idx_order_status', columns: ['status']),
    new ORM\Index(name: 'idx_order_created', columns: ['created_at'])
])]
#[ApiResource(
    normalizationContext: ['groups' => ['order:read']],
    denormalizationContext: ['groups' => ['order:write']]
)]
class Order
{
    public const STATUS_PENDING = 'pending';
    public const STATUS_PAID = 'paid';
    public const STATUS_PREPARING = 'preparing';
    public const STATUS_READY = 'ready';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_CANCELLED = 'cancelled';

    private static $allowedStatuses = [
        self::STATUS_PENDING,
        self::STATUS_PAID,
        self::STATUS_PREPARING,
        self::STATUS_READY,
        self::STATUS_COMPLETED,
        self::STATUS_CANCELLED
    ];

    private static $statusTexts = [
        self::STATUS_PENDING => 'En attente',
        self::STATUS_PAID => 'Payée',
        self::STATUS_PREPARING => 'En préparation',
        self::STATUS_READY => 'Prête',
        self::STATUS_COMPLETED => 'Terminée',
        self::STATUS_CANCELLED => 'Annulée'
    ];

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'integer')]
    #[Groups(['order:read'])]
    private ?int $id = null;

    #[ORM\Column(type: 'string', length: 50)]
    #[Assert\Choice(choices: ['pending', 'paid', 'preparing', 'ready', 'completed', 'cancelled'])]
    #[Groups(['order:read', 'order:write'])]
    private string $status = self::STATUS_PENDING;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)]
    #[Assert\NotBlank]
    #[Assert\PositiveOrZero]
    #[Groups(['order:read'])]
    private string $total = '0.00';

    #[ORM\ManyToOne(inversedBy: 'orders', targetEntity: User::class)]
    #[ORM\JoinColumn(name: 'user_id', referencedColumnName: 'id', nullable: false)]
    #[Groups(['order:read', 'order:write'])]
    private User $user;

    #[ORM\OneToMany(mappedBy: 'order', targetEntity: OrderItem::class, cascade: ['persist', 'remove'], orphanRemoval: true)]
    #[Groups(['order:read', 'order:write'])]
    private Collection $orderItems;

    #[ORM\Column(type: 'datetime')]
    #[Groups(['order:read'])]
    private \DateTimeInterface $createdAt;

    #[ORM\Column(type: 'datetime', nullable: true)]
    #[Groups(['order:read'])]
    private ?\DateTimeInterface $updatedAt = null;

    #[ORM\OneToOne(mappedBy: 'order', targetEntity: Invoice::class)]
    private ?Invoice $invoice = null;

    public function __construct()
    {
        $this->orderItems = new ArrayCollection();
        $this->createdAt = new \DateTime();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getStatus(): string
    {
        return $this->status;
    }

    public function setStatus(string $status): self
    {
        if (!in_array($status, self::$allowedStatuses)) {
            throw new \InvalidArgumentException("Invalid status: $status");
        }
        $this->status = $status;
        return $this;
    }

    public function getStatusText(): string
    {
        return self::$statusTexts[$this->status] ?? $this->status;
    }

    public function getTotal(): float
    {
        return (float) $this->total;
    }

    public function setTotal(float $total): self
    {
        if ($total < 0) {
            throw new \InvalidArgumentException("Total cannot be negative");
        }
        
        $this->total = number_format($total, 2, '.', '');
        return $this;
    }

    public function getUser(): User
    {
        return $this->user;
    }

    public function setUser(User $user): self
    {
        $this->user = $user;
        return $this;
    }

    /** @return Collection<int, OrderItem> */
    public function getOrderItems(): Collection
    {
        return $this->orderItems;
    }

    public function addOrderItem(OrderItem $orderItem): self
    {
        if (!$this->orderItems->contains($orderItem)) {
            $this->orderItems->add($orderItem);
            $orderItem->setOrder($this);
        }
        return $this;
    }

    public function removeOrderItem(OrderItem $orderItem): self
    {
        if ($this->orderItems->removeElement($orderItem)) {
            if ($orderItem->getOrder() === $this) {
                $orderItem->setOrder(null);
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

    public function calculateTotal(): void
    {
        $total = 0.0;
        foreach ($this->orderItems as $item) {
            $total += $item->getSubtotal();
        }
        
        if ($total < 0) {
            $total = 0.0;
        }
        
        $this->setTotal($total);
    }

    public function getInvoice(): ?Invoice
    {
        return $this->invoice;
    }

    public function setInvoice(?Invoice $invoice): self
    {
        $this->invoice = $invoice;
        if ($invoice && $invoice->getOrder() !== $this) {
            $invoice->setOrder($this);
        }
        return $this;
    }

    public function generateInvoice(): Invoice
    {
        if ($this->invoice) {
            throw new \RuntimeException('Invoice already exists for this order');
        }

        $invoice = new Invoice();
        $invoice->setAmount($this->getTotal());
        $invoice->setOrder($this);
        $invoice->setCreatedAt(new \DateTime());

        $this->setInvoice($invoice);

        return $invoice;
    }

    public function canBeModified(): bool
    {
        return in_array($this->status, [
            self::STATUS_PENDING,
            self::STATUS_PAID
        ]);
    }

    public static function getAllowedStatuses(): array
    {
        return self::$allowedStatuses;
    }

    public static function getStatusTexts(): array
    {
        return self::$statusTexts;
    }
}