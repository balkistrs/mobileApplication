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
                'Access-Control-Allow-Methods' => 'POST, OPTIONS',
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

            $orderData = [
                'id' => $order->getId(),
                'status' => $order->getStatus(),
                'total' => $order->getTotal(),
                'created_at' => $order->getCreatedAt()->format('Y-m-d H:i:s'),
                'items' => []
            ];

            foreach ($order->getOrderItems() as $item) {
                $product = $item->getProduct();
                $unitPrice = $item->getUnitPrice();
                
                if ($unitPrice === null) {
                    $unitPrice = 0.0;
                }
                
                $orderData['items'][] = [
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
            $orders = $this->entityManager->getRepository(Order::class)->findAll();
            
            $ordersData = [];
            foreach ($orders as $order) {
                $orderData = [
                    'id' => $order->getId(),
                    'status' => $order->getStatus(),
                    'total' => $order->getTotal(),
                    'created_at' => $order->getCreatedAt()->format('Y-m-d H:i:s'),
                    'items_count' => $order->getOrderItems()->count()
                ];
                $ordersData[] = $orderData;
            }

            return new JsonResponse($ordersData, 200, [
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

    #[Route('/{id}/status', name: 'api_order_update_status', methods: ['PATCH', 'OPTIONS'])]
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
                'status' => 'success',
                'message' => 'Order status updated successfully',
                'order_id' => $order->getId(),
                'new_status' => $order->getStatus()
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
}