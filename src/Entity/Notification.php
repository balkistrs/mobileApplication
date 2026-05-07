<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Serializer\Annotation\Groups;
use App\Repository\NotificationRepository;

#[ORM\Entity(repositoryClass: NotificationRepository::class)]
#[ORM\Table(name: 'notifications')]
#[ApiResource(
    normalizationContext: ['groups' => ['notification:read']],
    denormalizationContext: ['groups' => ['notification:write']]
)]
class Notification
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'integer')]
    #[Groups(['notification:read'])]
    private ?int $id = null;

    #[ORM\ManyToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false)]
    #[Groups(['notification:read'])]
    private ?User $user = null;

    #[ORM\Column(type: 'string', length: 255)]
    #[Groups(['notification:read', 'notification:write'])]
    private string $type; // 'new_order', 'order_status_changed', 'order_ready_for_delivery', etc.

    #[ORM\Column(type: 'string', length: 255)]
    #[Groups(['notification:read', 'notification:write'])]
    private string $title;

    #[ORM\Column(type: 'text')]
    #[Groups(['notification:read', 'notification:write'])]
    private string $message;

    #[ORM\Column(type: 'integer', nullable: true)]
    #[Groups(['notification:read', 'notification:write'])]
    private ?int $orderId = null;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['notification:read', 'notification:write'])]
    private bool $isRead = false;

    #[ORM\Column(type: 'datetime')]
    #[Groups(['notification:read'])]
    private \DateTimeInterface $createdAt;

    public function __construct()
    {
        $this->createdAt = new \DateTime();
    }

    public function getId(): ?int
    {
        return $this->id;
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

    public function getType(): string
    {
        return $this->type;
    }

    public function setType(string $type): self
    {
        $this->type = $type;
        return $this;
    }

    public function getTitle(): string
    {
        return $this->title;
    }

    public function setTitle(string $title): self
    {
        $this->title = $title;
        return $this;
    }

    public function getMessage(): string
    {
        return $this->message;
    }

    public function setMessage(string $message): self
    {
        $this->message = $message;
        return $this;
    }

    public function getOrderId(): ?int
    {
        return $this->orderId;
    }

    public function setOrderId(?int $orderId): self
    {
        $this->orderId = $orderId;
        return $this;
    }

    public function isRead(): bool
    {
        return $this->isRead;
    }

    public function setIsRead(bool $isRead): self
    {
        $this->isRead = $isRead;
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