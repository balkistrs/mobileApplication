<?php

namespace App\Service;

use App\Entity\Order;
use App\Entity\Invoice;
use Doctrine\ORM\EntityManagerInterface;

class PaymentService
{
    private EntityManagerInterface $entityManager;

    public function __construct(EntityManagerInterface $entityManager)
    {
        $this->entityManager = $entityManager;
    }

    public function processPayment(array $paymentData): array
    {
        $order = $this->entityManager->getRepository(Order::class)->find($paymentData['order_id']);

        if (!$order) {
            throw new \InvalidArgumentException('Order not found');
        }

        if ($order->getStatus() === Order::STATUS_PAID) {
            throw new \InvalidArgumentException('Order already paid');
        }

        if (abs($order->getTotal() - $paymentData['amount']) > 0.01) {
            throw new \InvalidArgumentException('Amount mismatch. Expected: ' . $order->getTotal() . ', Got: ' . $paymentData['amount']);
        }

        // Simulate payment processing
        $paymentSuccess = $this->simulatePaymentProcessing($paymentData);

        if (!$paymentSuccess) {
            throw new \InvalidArgumentException('Payment declined by bank');
        }

        $order->setStatus(Order::STATUS_PAID);
        $order->setUpdatedAt(new \DateTime());

        // Create invoice if it doesn't exist
        if (!$order->getInvoice()) {
            $invoice = new Invoice();
            $invoice->setAmount($order->getTotal());
            $invoice->setOrder($order);
            $invoice->setCreatedAt(new \DateTime());

            $this->entityManager->persist($invoice);
            $order->setInvoice($invoice);
        }

        $this->entityManager->flush();

        return [
            'order_id' => $order->getId(),
            'status' => $order->getStatus(),
            'amount' => $order->getTotal(),
            'payment_status' => 'completed',
            'timestamp' => (new \DateTime())->format('Y-m-d H:i:s')
        ];
    }

    private function simulatePaymentProcessing(array $paymentData): bool
    {
        // Simple payment simulation
        // In real application, integrate with Stripe, PayPal, etc.
        
        // Always accept payments for demo
        return true;
        
        // For testing failures, you can use:
        // return rand(1, 100) > 20; // 80% success rate
    }

    public function getOrderStatus(int $orderId): ?string
    {
        $order = $this->entityManager->getRepository(Order::class)->find($orderId);
        return $order ? $order->getStatus() : null;
    }
}