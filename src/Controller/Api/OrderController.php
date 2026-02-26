<?php

namespace App\Controller\Api;

use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\Product;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;
use Psr\Log\LoggerInterface;

#[Route('/api/orders')]
class OrderController extends AbstractController
{
    private $entityManager;
    private $logger;

    public function __construct(
        EntityManagerInterface $entityManager,
        LoggerInterface $logger
    ) {
        $this->entityManager = $entityManager;
        $this->logger = $logger;
    }

    #[Route('', name: 'api_order_create', methods: ['POST', 'OPTIONS'])]
    public function createOrder(Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'POST, OPTIONS, GET, PUT, DELETE',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization, X-Requested-With',
            ]);
        }

        try {
            $this->logger->info('Creating new order');
            
            $content = $request->getContent();
            $data = json_decode($content, true);

            if (json_last_error() !== JSON_ERROR_NONE) {
                return new JsonResponse([
                    'error' => 'Invalid JSON format'
                ], 400, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Validate required fields
            if (!isset($data['items']) || !is_array($data['items']) || empty($data['items'])) {
                return new JsonResponse([
                    'error' => 'Items are required and must be a non-empty array'
                ], 400, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Create new order
            $order = new Order();
            $order->setStatus(Order::STATUS_PENDING);
            $order->setCreatedAt(new \DateTime());

            $total = 0.0;

            // Add order items
            foreach ($data['items'] as $itemData) {
                if (!isset($itemData['product_id']) || !isset($itemData['quantity'])) {
                    return new JsonResponse([
                        'error' => 'Each item must have product_id and quantity'
                    ], 400, [
                        'Access-Control-Allow-Origin' => '*',
                    ]);
                }

                $product = $this->entityManager->getRepository(Product::class)->find($itemData['product_id']);
                
                if (!$product) {
                    return new JsonResponse([
                        'error' => 'Product not found: ' . $itemData['product_id']
                    ], 404, [
                        'Access-Control-Allow-Origin' => '*',
                    ]);
                }

                // Vérifier et valider le prix du produit
                $price = $product->getPrice();
                if ($price === null) {
                    $this->logger->warning('Product has null price: ' . $itemData['product_id']);
                    $price = 0.0;
                }
                
                $price = (float) $price;
                if ($price < 0) {
                    $this->logger->warning('Product has negative price: ' . $itemData['product_id'] . ', price: ' . $price);
                    $price = 0.0;
                }

                // Valider et corriger la quantité
                $quantity = (int) $itemData['quantity'];
                if ($quantity < 1) {
                    $this->logger->warning('Invalid quantity: ' . $quantity . ', setting to 1');
                    $quantity = 1;
                }

                $orderItem = new OrderItem();
                $orderItem->setProduct($product);
                $orderItem->setQuantity($quantity);
                $orderItem->setUnitPrice($price);
                $orderItem->setOrder($order);

                $itemTotal = $price * $quantity;
                $total += $itemTotal;

                $this->entityManager->persist($orderItem);
                $order->addOrderItem($orderItem);
                
                $this->logger->info('Added item: product_id=' . $product->getId() . ', price=' . $price . ', quantity=' . $quantity . ', itemTotal=' . $itemTotal);
            }

            // Validation du total
            if ($total < 0) {
                $total = 0.0;
            }
            
            $order->setTotal($total);
            $this->entityManager->persist($order);
            $this->entityManager->flush();

            $this->logger->info('Order created successfully: id=' . $order->getId() . ', total=' . $total);

            return new JsonResponse([
                'status' => 'success',
                'message' => 'Order created successfully',
                'order_id' => $order->getId(),
                'total' => $total,
                'items_count' => count($data['items'])
            ], Response::HTTP_CREATED, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\InvalidArgumentException $e) {
            $this->logger->error('Invalid argument: ' . $e->getMessage());
            return new JsonResponse([
                'status' => 'error',
                'message' => 'Invalid data: ' . $e->getMessage()
            ], Response::HTTP_BAD_REQUEST, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        } catch (\Exception $e) {
            $this->logger->error('Order creation error: ' . $e->getMessage());
            return new JsonResponse([
                'status' => 'error',
                'message' => 'Failed to create order: ' . $e->getMessage()
            ], Response::HTTP_INTERNAL_SERVER_ERROR, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    #[Route('/user/ordersUser', name: 'api_user_orders', methods: ['GET', 'OPTIONS'])]
    public function getUserOrders(Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'GET, OPTIONS, PUT, DELETE',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization, X-Requested-With',
            ]);
        }

        try {
            // Récupérer l'utilisateur connecté
            $user = $this->getUser();
            
            if (!$user) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Non authentifié'
                ], 401, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            /** @var \App\Entity\User $user */
            $this->logger->info('Fetching orders for user: ' . $user->getId());

            // Récupérer les commandes de l'utilisateur
            $orders = $this->entityManager->getRepository(Order::class)
                ->findBy(
                    ['user' => $user],
                    ['createdAt' => 'DESC']
                );

            $ordersData = [];
            foreach ($orders as $order) {
                $items = [];
                $totalItems = 0;
                
                foreach ($order->getOrderItems() as $item) {
                    $product = $item->getProduct();
                    $items[] = [
                        'id' => $item->getId(),
                        'product_id' => $product->getId(),
                        'name' => $product->getName(),
                        'quantity' => $item->getQuantity(),
                        'price' => $item->getUnitPrice(),
                        'total' => $item->getUnitPrice() * $item->getQuantity()
                    ];
                    $totalItems++;
                }

                $ordersData[] = [
                    'id' => $order->getId(),
                    'status' => $order->getStatus(),
                    'statusText' => $this->getStatusText($order->getStatus()),
                    'total' => $order->getTotal(),
                    'createdAt' => $order->getCreatedAt()->format('Y-m-d H:i:s'),
                    'updatedAt' => $order->getUpdatedAt() ? $order->getUpdatedAt()->format('Y-m-d H:i:s') : null,
                    'orderItems' => $items,
                    'items_count' => $totalItems
                ];
            }

            return new JsonResponse([
                'success' => true,
                'data' => [
                    'orders' => $ordersData,
                    'count' => count($ordersData)
                ]
            ], 200, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\Exception $e) {
            $this->logger->error('Failed to fetch user orders: ' . $e->getMessage());
            return new JsonResponse([
                'success' => false,
                'error' => 'Erreur lors de la récupération des commandes: ' . $e->getMessage()
            ], 500, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    #[Route('/orders/{orderId}/items/{itemId}', name: 'api_order_update_item', methods: ['PUT', 'OPTIONS'])]
    public function updateOrderItem(int $orderId, int $itemId, Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'PUT, OPTIONS, DELETE',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization, X-Requested-With',
            ]);
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Non authentifié'
                ], 401, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $order = $this->entityManager->getRepository(Order::class)->find($orderId);
            
            if (!$order) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Commande non trouvée'
                ], 404, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Vérifier que la commande appartient à l'utilisateur
            if ($order->getUser() !== $user) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Accès non autorisé à cette commande'
                ], 403, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Vérifier que la commande peut être modifiée (seulement si en attente ou payée)
            if (!in_array($order->getStatus(), [Order::STATUS_PENDING, Order::STATUS_PAID])) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Cette commande ne peut plus être modifiée'
                ], 400, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $orderItem = $this->entityManager->getRepository(OrderItem::class)->find($itemId);
            
            if (!$orderItem || $orderItem->getOrder() !== $order) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Article non trouvé dans cette commande'
                ], 404, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $content = $request->getContent();
            $data = json_decode($content, true);

            if (!isset($data['quantity'])) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'La quantité est requise'
                ], 400, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $newQuantity = (int) $data['quantity'];
            
            if ($newQuantity < 1) {
                // Si quantité < 1, supprimer l'article
                $this->entityManager->remove($orderItem);
                $this->logger->info('Removed item: ' . $itemId . ' from order: ' . $orderId);
            } else {
                // Mettre à jour la quantité
                $orderItem->setQuantity($newQuantity);
                $this->logger->info('Updated item: ' . $itemId . ' quantity to: ' . $newQuantity);
            }

            // Recalculer le total de la commande
            $newTotal = 0;
            foreach ($order->getOrderItems() as $item) {
                $newTotal += $item->getUnitPrice() * $item->getQuantity();
            }
            $order->setTotal($newTotal);
            $order->setUpdatedAt(new \DateTime());

            $this->entityManager->flush();

            // Récupérer les articles mis à jour
            $updatedItems = [];
            foreach ($order->getOrderItems() as $item) {
                $product = $item->getProduct();
                $updatedItems[] = [
                    'id' => $item->getId(),
                    'product_id' => $product->getId(),
                    'name' => $product->getName(),
                    'quantity' => $item->getQuantity(),
                    'price' => $item->getUnitPrice(),
                    'total' => $item->getUnitPrice() * $item->getQuantity()
                ];
            }

            return new JsonResponse([
                'success' => true,
                'message' => $newQuantity < 1 ? 'Article supprimé avec succès' : 'Quantité mise à jour avec succès',
                'data' => [
                    'order_id' => $order->getId(),
                    'total' => $order->getTotal(),
                    'items' => $updatedItems
                ]
            ], 200, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\Exception $e) {
            $this->logger->error('Failed to update order item: ' . $e->getMessage());
            return new JsonResponse([
                'success' => false,
                'error' => 'Erreur lors de la mise à jour: ' . $e->getMessage()
            ], 500, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    #[Route('/orders/{orderId}/items/{itemId}', name: 'api_order_delete_item', methods: ['DELETE', 'OPTIONS'])]
    public function deleteOrderItem(int $orderId, int $itemId, Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'DELETE, OPTIONS',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization, X-Requested-With',
            ]);
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Non authentifié'
                ], 401, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $order = $this->entityManager->getRepository(Order::class)->find($orderId);
            
            if (!$order) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Commande non trouvée'
                ], 404, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Vérifier que la commande appartient à l'utilisateur
            if ($order->getUser() !== $user) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Accès non autorisé à cette commande'
                ], 403, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Vérifier que la commande peut être modifiée
            if (!in_array($order->getStatus(), [Order::STATUS_PENDING, Order::STATUS_PAID])) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Cette commande ne peut plus être modifiée'
                ], 400, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $orderItem = $this->entityManager->getRepository(OrderItem::class)->find($itemId);
            
            if (!$orderItem || $orderItem->getOrder() !== $order) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Article non trouvé dans cette commande'
                ], 404, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Supprimer l'article
            $this->entityManager->remove($orderItem);

            // Recalculer le total de la commande
            $newTotal = 0;
            foreach ($order->getOrderItems() as $item) {
                if ($item !== $orderItem) {
                    $newTotal += $item->getUnitPrice() * $item->getQuantity();
                }
            }
            
            if ($newTotal > 0) {
                $order->setTotal($newTotal);
            } else {
                // Si plus d'articles, annuler la commande
                $order->setStatus(Order::STATUS_CANCELLED);
                $order->setTotal(0);
            }
            
            $order->setUpdatedAt(new \DateTime());

            $this->entityManager->flush();

            $this->logger->info('Deleted item: ' . $itemId . ' from order: ' . $orderId);

            return new JsonResponse([
                'success' => true,
                'message' => 'Article supprimé avec succès',
                'data' => [
                    'order_id' => $order->getId(),
                    'total' => $order->getTotal(),
                    'status' => $order->getStatus()
                ]
            ], 200, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\Exception $e) {
            $this->logger->error('Failed to delete order item: ' . $e->getMessage());
            return new JsonResponse([
                'success' => false,
                'error' => 'Erreur lors de la suppression: ' . $e->getMessage()
            ], 500, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    #[Route('/{id}', name: 'api_order_get', methods: ['GET', 'OPTIONS'])]
    public function getOrder(int $id, Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'GET, OPTIONS',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization, X-Requested-With',
            ]);
        }

        try {
            $order = $this->entityManager->getRepository(Order::class)->find($id);

            if (!$order) {
                return new JsonResponse([
                    'error' => 'Order not found'
                ], 404, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Vérifier que l'utilisateur a accès à cette commande
            $user = $this->getUser();
            if ($order->getUser() !== $user) {
                return new JsonResponse([
                    'error' => 'Accès non autorisé à cette commande'
                ], 403, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $orderData = [
                'id' => $order->getId(),
                'status' => $order->getStatus(),
                'statusText' => $this->getStatusText($order->getStatus()),
                'total' => $order->getTotal(),
                'createdAt' => $order->getCreatedAt()->format('Y-m-d H:i:s'),
                'updatedAt' => $order->getUpdatedAt() ? $order->getUpdatedAt()->format('Y-m-d H:i:s') : null,
                'items' => []
            ];

            foreach ($order->getOrderItems() as $item) {
                $product = $item->getProduct();
                $unitPrice = $item->getUnitPrice();
                
                if ($unitPrice === null) {
                    $unitPrice = 0.0;
                }
                
                $orderData['items'][] = [
                    'id' => $item->getId(),
                    'product_id' => $product->getId(),
                    'product_name' => $product->getName(),
                    'quantity' => $item->getQuantity(),
                    'unit_price' => $unitPrice,
                    'total' => $unitPrice * $item->getQuantity()
                ];
            }

            return new JsonResponse($orderData, 200, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\Exception $e) {
            $this->logger->error('Failed to get order: ' . $e->getMessage());
            return new JsonResponse([
                'error' => 'Failed to get order: ' . $e->getMessage()
            ], 500, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    #[Route('', name: 'api_order_list', methods: ['GET', 'OPTIONS'])]
    public function listOrders(Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'GET, OPTIONS',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization, X-Requested-With',
            ]);
        }

        try {
            // Autoriser les admins, chefs et serveurs
            $user = $this->getUser();
            $allowedRoles = ['ROLE_ADMIN', 'ROLE_CHEF', 'ROLE_SERVEUR'];
            if (empty(array_intersect($user->getRoles(), $allowedRoles))) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Accès non autorisé'
                ], 403, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $orders = $this->entityManager->getRepository(Order::class)->findAll();
            
            $ordersData = [];
            foreach ($orders as $order) {
                $orderData = [
                    'id' => $order->getId(),
                    'user_id' => $order->getUser()->getId(),
                    'user_email' => $order->getUser()->getEmail(),
                    'status' => $order->getStatus(),
                    'statusText' => $this->getStatusText($order->getStatus()),
                    'total' => $order->getTotal(),
                    'created_at' => $order->getCreatedAt()->format('Y-m-d H:i:s'),
                    'items_count' => $order->getOrderItems()->count()
                ];
                $ordersData[] = $orderData;
            }

            return new JsonResponse([
                'success' => true,
                'data' => $ordersData
            ], 200, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\Exception $e) {
            $this->logger->error('Failed to list orders: ' . $e->getMessage());
            return new JsonResponse([
                'error' => 'Failed to list orders: ' . $e->getMessage()
            ], 500, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    #[Route('/{id}/status', name: 'api_order_update_status', methods: ['PATCH','PUT', 'OPTIONS'])]
    public function updateOrderStatus(int $id, Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'PATCH, OPTIONS',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization, X-Requested-With',
            ]);
        }

        try {
            $order = $this->entityManager->getRepository(Order::class)->find($id);

            if (!$order) {
                return new JsonResponse([
                    'error' => 'Order not found'
                ], 404, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Vérifier que l'utilisateur a accès à cette commande
            $user = $this->getUser();
            $allowedRoles = ['ROLE_ADMIN', 'ROLE_CHEF', 'ROLE_SERVEUR'];
            if ($order->getUser() !== $user && empty(array_intersect($user->getRoles(), $allowedRoles))) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Accès non autorisé à cette commande'
                ], 403, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $content = $request->getContent();
            $data = json_decode($content, true);

            if (!isset($data['status'])) {
                return new JsonResponse([
                    'error' => 'Status is required'
                ], 400, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            $order->setStatus($data['status']);
            $order->setUpdatedAt(new \DateTime());

            $this->entityManager->flush();

            return new JsonResponse([
                'success' => true,
                'message' => 'Order status updated successfully',
                'order_id' => $order->getId(),
                'new_status' => $order->getStatus(),
                'statusText' => $this->getStatusText($order->getStatus())
            ], 200, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\InvalidArgumentException $e) {
            $this->logger->error('Invalid status: ' . $e->getMessage());
            return new JsonResponse([
                'error' => 'Invalid status: ' . $e->getMessage()
            ], 400, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        } catch (\Exception $e) {
            $this->logger->error('Failed to update order status: ' . $e->getMessage());
            return new JsonResponse([
                'error' => 'Failed to update order status: ' . $e->getMessage()
            ], 500, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    // Méthode utilitaire pour convertir le status en texte lisible
    private function getStatusText(string $status): string
    {
        return match($status) {
            Order::STATUS_PENDING => 'En attente',
            Order::STATUS_PAID => 'Payée',
            Order::STATUS_PREPARING => 'En préparation',
            Order::STATUS_READY => 'Prête',
            Order::STATUS_COMPLETED => 'Terminée',
            Order::STATUS_CANCELLED => 'Annulée',
            default => $status
        };
    }
}