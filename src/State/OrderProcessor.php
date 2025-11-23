<?php

namespace App\State;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use App\Entity\Order;
use Doctrine\ORM\EntityManagerInterface;

class OrderProcessor implements ProcessorInterface
{
    public function __construct(
        private EntityManagerInterface $entityManager
    ) {
    }

    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = [])
    {
        if ($data instanceof Order) {
            // Calculer le total de la commande
            $data->calculateTotal();

            // Calculer les sous-totaux des items
            foreach ($data->getOrderItems() as $orderItem) {
                $orderItem->calculateSubtotal();
            }

            $this->entityManager->persist($data);
            $this->entityManager->flush();
        }

        return $data;
    }
}