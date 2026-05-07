<?php

namespace App\Dto;

use Symfony\Component\Validator\Constraints as Assert;

class CreateOrderRequest
{
    #[Assert\NotBlank]
    #[Assert\Positive]
    public float $total;

    #[Assert\NotBlank]
    #[Assert\Count(min: 1)]
    #[Assert\Valid]
    public array $items;

    public static function fromArray(array $data): self
    {
        $dto = new self();
        $dto->total = (float)($data['total'] ?? 0);
        $dto->items = $data['items'] ?? [];

        return $dto;
    }
}