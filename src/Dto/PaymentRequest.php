<?php

namespace App\Dto;

class PaymentRequest
{
    public int $clientId;
    public float $amount;
    public string $cardNumber;
    public string $cardHolder;
    public string $expiryDate;
    public string $cvv;
    public array $orderItems; // Add this for order items

    public function __construct(
        int $clientId,
        float $amount,
        string $cardNumber,
        string $cardHolder,
        string $expiryDate,
        string $cvv,
        array $orderItems = []
    ) {
        $this->clientId = $clientId;
        $this->amount = $amount;
        $this->cardNumber = $cardNumber;
        $this->cardHolder = $cardHolder;
        $this->expiryDate = $expiryDate;
        $this->cvv = $cvv;
        $this->orderItems = $orderItems;
    }
}