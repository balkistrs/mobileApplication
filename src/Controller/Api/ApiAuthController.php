<?php

namespace App\Controller\Api;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Doctrine\ORM\EntityManagerInterface;
use App\Entity\User;
use App\Entity\Order;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Component\Security\Core\Authentication\Token\Storage\TokenStorageInterface;
use App\Entity\Notification;
use App\Entity\Product;
use App\Entity\OrderItem;

class ApiAuthController extends AbstractController
{
    private $jwtManager;
    private $em;
    private $tokenStorage;

    public function __construct(
        JWTTokenManagerInterface $jwtManager, 
        EntityManagerInterface $em,
        TokenStorageInterface $tokenStorage
    ) {
        $this->jwtManager = $jwtManager;
        $this->em = $em;
        $this->tokenStorage = $tokenStorage;
    }

    #[Route('/api/register', name: 'api_register', methods: ['POST', 'OPTIONS'])]
    public function register(Request $request, UserPasswordHasherInterface $passwordHasher): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $data = $this->getRequestData($request);

            if (!$data || !isset($data['email']) || !isset($data['password'])) {
                return $this->jsonError('Email et mot de passe requis', 400);
            }

            $email = trim($data['email']);
            $password = $data['password'];
            $role = $data['role'] ?? 'ROLE_CLIENT';

            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                return $this->jsonError('Email invalide', 400);
            }

            if (strlen($password) < 6) {
                return $this->jsonError('Le mot de passe doit contenir au moins 6 caractères', 400);
            }

            $allowedRoles = ['ROLE_CLIENT', 'ROLE_CHEF', 'ROLE_SERVEUR', 'ROLE_ADMIN'];
            if (!in_array($role, $allowedRoles)) {
                return $this->jsonError('Rôle invalide', 400);
            }

            $existingUser = $this->em->getRepository(User::class)->findOneBy(['email' => $email]);
            if ($existingUser) {
                return $this->jsonError('Un utilisateur avec cet email existe déjà', 409);
            }

            $user = new User();
            $user->setEmail($email);
            $user->setPassword($passwordHasher->hashPassword($user, $password));
            $user->setRoles([$role]);
            // Set a default name from email if not provided
            $name = $data['name'] ?? explode('@', $email)[0];
            $user->setName($name);

            $this->em->persist($user);
            $this->em->flush();

            $token = $this->jwtManager->create($user);

            return $this->jsonSuccess([
                'token' => $token,
                'user' => [
                    'id' => $user->getId(),
                    'email' => $user->getEmail(),
                    'roles' => $user->getRoles()
                ]
            ], 201);

        } catch (\Exception $e) {
            error_log('Registration error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/login', name: 'api_login', methods: ['POST', 'OPTIONS'])]
    public function login(Request $request, UserPasswordHasherInterface $passwordHasher): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $data = $this->getRequestData($request);

            if (!$data || !isset($data['email']) || !isset($data['password'])) {
                return $this->jsonError('Données invalides', 400);
            }

            $email = $data['email'];
            $password = $data['password'];

            $user = $this->em->getRepository(User::class)->findOneBy(['email' => $email]);

            if (!$user) {
                return $this->jsonError('Email ou mot de passe incorrect', 401);
            }

            if (!$passwordHasher->isPasswordValid($user, $password)) {
                return $this->jsonError('Email ou mot de passe incorrect', 401);
            }

            $token = $this->jwtManager->create($user);

            return $this->jsonSuccess([
                'token' => $token,
                'user' => [
                    'id' => $user->getId(),
                    'email' => $user->getEmail(),
                    'roles' => $user->getRoles()
                ]
            ]);

        } catch (\Exception $e) {
            error_log('Login error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur', 500);
        }
    }

    #[Route('/api/admin/users', name: 'api_admin_users', methods: ['GET', 'OPTIONS'])]
    public function getUsers(Request $request): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            if (!in_array('ROLE_ADMIN', $user->getRoles())) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $users = $this->em->getRepository(User::class)->findAll();
            $usersData = [];

            foreach ($users as $userItem) {
                $usersData[] = [
                    'id' => $userItem->getId(),
                    'email' => $userItem->getEmail(),
                    'roles' => $userItem->getRoles(),
                ];
            }

            return $this->jsonSuccess(['users' => $usersData]);

        } catch (\Exception $e) {
            error_log('Get users error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/orders', name: 'api_orders', methods: ['GET', 'OPTIONS'])]
    public function getOrders(Request $request): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $userRoles = $user->getRoles();
            $allowedRoles = ['ROLE_CHEF', 'ROLE_SERVEUR', 'ROLE_ADMIN'];
            
            if (empty(array_intersect($userRoles, $allowedRoles))) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            // Récupérer les commandes depuis la base
            $statusFilter = $request->query->get('status');

            $repo = $this->em->getRepository(Order::class);

            if ($statusFilter) {
                $ordersEntities = $repo->findBy(['status' => $statusFilter], ['createdAt' => 'DESC']);
            } else {
                $ordersEntities = $repo->findBy([], ['createdAt' => 'DESC']);
            }

            $orders = [];
            foreach ($ordersEntities as $order) {
                $items = [];
                foreach ($order->getOrderItems() as $item) {
                    $product = $item->getProduct();
                    // OrderItem does not define getName(); use the product name when available
                    $items[] = $product ? $product->getName() : 'Article';
                }

                $orders[] = [
                    'id' => $order->getId(),
                    'client' => $order->getUser() ? $order->getUser()->getEmail() : null,
                    'items' => $items,
                    // Use the Order entity helper to translate status to human text
                    'status' => $order->getStatusText(),
                    'rawStatus' => $order->getStatus(),
                    'createdAt' => $order->getCreatedAt() ? $order->getCreatedAt()->format('Y-m-d H:i:s') : null
                ];
            }

            return $this->jsonSuccess(['orders' => $orders]);

        } catch (\Exception $e) {
            error_log('Get orders error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur', 500);
        }
    }

    #[Route('/api/orderspayment', name: 'api_create_order_pay', methods: ['POST', 'OPTIONS'])]
    public function createOrderPay(Request $request, EntityManagerInterface $em): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            
            if (!$user) {
                $token = $this->tokenStorage->getToken();
                if ($token) {
                    $user = $token->getUser();
                }
                
                if (!$user || $user === 'anon.' || is_string($user)) {
                    return $this->jsonError('Non authentifié', 401);
                }
            }
            
            if (!$user instanceof User) {
                return $this->jsonError('Utilisateur invalide', 401);
            }

            $data = $this->getRequestData($request);
            
            if (!isset($data['items']) || !is_array($data['items'])) {
                return $this->jsonError('Données invalides: items requis et doivent être un tableau', 400);
            }

            if (empty($data['items'])) {
                return $this->jsonError('Le panier est vide', 400);
            }

            $order = new Order();
            $order->setUser($user);
            $order->setStatus('pending');
            $order->setCreatedAt(new \DateTime());
            $order->setUpdatedAt(new \DateTime());

            $total = 0;

            foreach ($data['items'] as $itemIndex => $itemData) {
                if (!isset($itemData['product_id']) || !isset($itemData['quantity'])) {
                    return $this->jsonError("Données d'article invalides à l'index $itemIndex: product_id et quantity requis", 400);
                }

                $productId = $itemData['product_id'];
                $quantity = $itemData['quantity'];

                if (!is_numeric($productId) || $productId <= 0) {
                    return $this->jsonError("Product_id invalide à l'index $itemIndex", 400);
                }

                if (!is_numeric($quantity) || $quantity <= 0) {
                    return $this->jsonError("Quantity invalide à l'index $itemIndex", 400);
                }

                $product = $em->getRepository(Product::class)->find($productId);
                if (!$product) {
                    return $this->jsonError('Produit non trouvé: ' . $productId, 404);
                }

                $orderItem = new OrderItem();
                $orderItem->setProduct($product);
                $orderItem->setQuantity($quantity);
                $orderItem->setOrder($order);
                
                $itemPrice = $product->getPrice() * $quantity;
                $total += $itemPrice;

                $em->persist($orderItem);
            }

            $order->setTotal($total);
            $em->persist($order);
            $em->flush();

            // Créer une notification pour tous les chefs
            $chefs = $this->em->getRepository(User::class)->findByRole('ROLE_CHEF');
            foreach ($chefs as $chef) {
                $this->createNotification(
                    $chef,
                    'new_order',
                    'Nouvelle commande',
                    "Nouvelle commande #{$order->getId()} de {$user->getEmail()}",
                    $order->getId()
                );
            }

            return new JsonResponse([
                'success' => true,
                'order_id' => $order->getId(),
                'status' => $order->getStatus(),
                'total' => $total,
                'message' => 'Commande créée avec succès'
            ], 201, $this->getCorsHeaders());

        } catch (\Exception $e) {
            error_log('Create order error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/test', name: 'api_test', methods: ['GET', 'OPTIONS'])]
    public function test(Request $request): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, $this->getCorsHeaders());
        }

        return new JsonResponse([
            'success' => true,
            'message' => 'API is working!',
            'timestamp' => time()
        ], 200, $this->getCorsHeaders());
    }

    #[Route('/api/users/{email}', name: 'api_update_user', methods: ['PUT', 'OPTIONS'])]
    public function updateUser(Request $request, string $email, UserPasswordHasherInterface $passwordHasher): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $currentUser = $this->getUser();
            if (!$currentUser) {
                return $this->jsonError('Non authentifié', 401);
            }

            // Allow admins to edit any user, or allow a user to edit their own profile
            $isAdmin = in_array('ROLE_ADMIN', $currentUser->getRoles());
            if (!$isAdmin && $currentUser->getUserIdentifier() !== $email) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $user = $this->em->getRepository(User::class)->findOneBy(['email' => $email]);
            if (!$user) {
                return $this->jsonError('Utilisateur non trouvé', 404);
            }

            $data = $this->getRequestData($request);

            if (isset($data['email'])) {
                $newEmail = trim($data['email']);
                if (!filter_var($newEmail, FILTER_VALIDATE_EMAIL)) {
                    return $this->jsonError('Email invalide', 400);
                }

                $existingUser = $this->em->getRepository(User::class)->findOneBy(['email' => $newEmail]);
                if ($existingUser && $existingUser->getId() !== $user->getId()) {
                    return $this->jsonError('Un utilisateur avec cet email existe déjà', 409);
                }

                $user->setEmail($newEmail);
            }

            if (isset($data['role'])) {
                $allowedRoles = ['ROLE_CLIENT', 'ROLE_CHEF', 'ROLE_SERVEUR', 'ROLE_ADMIN'];
                if (!in_array($data['role'], $allowedRoles)) {
                    return $this->jsonError('Rôle invalide', 400);
                }
                $user->setRoles([$data['role']]);
            }

            if (isset($data['name'])) {
                $newName = trim($data['name']);
                $user->setName($newName !== '' ? $newName : null);
            }

            if (isset($data['password']) && !empty($data['password'])) {
                if (strlen($data['password']) < 6) {
                    return $this->jsonError('Le mot de passe doit contenir au moins 6 caractères', 400);
                }
                $user->setPassword($passwordHasher->hashPassword($user, $data['password']));
            }

            $this->em->flush();

            return $this->jsonSuccess([
                'message' => 'Utilisateur modifié avec succès',
                'user' => [
                    'id' => $user->getId(),
                    'email' => $user->getEmail(),
                    'name' => $user->getName(),
                    'roles' => $user->getRoles()
                ]
            ]);

        } catch (\Exception $e) {
            error_log('Update user error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/users/{email}/vote', name: 'api_submit_vote', methods: ['PUT', 'OPTIONS'])]
    public function submitVote(Request $request, string $email): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $currentUser = $this->getUser();
            if (!$currentUser) {
                return $this->jsonError('Non authentifié', 401);
            }

            // Allow a user to vote for their own profile
            if ($currentUser->getUserIdentifier() !== $email) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $user = $this->em->getRepository(User::class)->findOneBy(['email' => $email]);
            if (!$user) {
                return $this->jsonError('Utilisateur non trouvé', 404);
            }

            $data = $this->getRequestData($request);

            if (!isset($data['vote']) || empty($data['vote'])) {
                return $this->jsonError('Le vote est requis', 400);
            }

            $vote = trim($data['vote']);
            
            // Validate vote is a number between 1 and 5
            if (!is_numeric($vote) || (int)$vote < 1 || (int)$vote > 5) {
                return $this->jsonError('Le vote doit être un nombre entre 1 et 5', 400);
            }

            // Update vote field directly
            $user->setVote($vote);
            $this->em->flush();

            return $this->jsonSuccess([
                'message' => 'Vote enregistré avec succès',
                'user' => [
                    'id' => $user->getId(),
                    'email' => $user->getEmail(),
                    'name' => $user->getName(),
                    'vote' => $vote,
                    'roles' => $user->getRoles()
                ]
            ]);

        } catch (\Exception $e) {
            error_log('Submit vote error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/user/orders', name: 'api_user_orders', methods: ['GET', 'OPTIONS'])]
    public function getUserOrders(Request $request): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $orders = $this->em->getRepository(Order::class)->findBy(['user' => $user], ['createdAt' => 'DESC']);
            
            $ordersData = [];
            foreach ($orders as $order) {
                $orderItems = [];
                if (method_exists($order, 'getOrderItems')) {
                    foreach ($order->getOrderItems() as $item) {
                        $orderItems[] = [
                            'name' => method_exists($item, 'getProduct') && $item->getProduct() ? 
                                     $item->getProduct()->getName() : 'Produit inconnu',
                            'quantity' => method_exists($item, 'getQuantity') ? $item->getQuantity() : 1,
                            'price' => method_exists($item, 'getUnitPrice') ? $item->getUnitPrice() : 0
                        ];
                    }
                }

                $ordersData[] = [
                    'id' => $order->getId(),
                    'status' => $order->getStatus(),
                    'total' => method_exists($order, 'getTotal') ? $order->getTotal() : 0,
                    'orderItems' => $orderItems,
                    'createdAt' => method_exists($order, 'getCreatedAt') && $order->getCreatedAt() ? 
                                  $order->getCreatedAt()->format('Y-m-d H:i:s') : 'Date inconnue',
                ];
            }

            return $this->jsonSuccess(['orders' => $ordersData]);

        } catch (\Exception $e) {
            error_log('Get user orders error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/admin/users/{email}', name: 'api_delete_user', methods: ['DELETE', 'OPTIONS'])]
    public function deleteUser(Request $request, string $email): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $currentUser = $this->getUser();
            if (!$currentUser) {
                return $this->jsonError('Non authentifié', 401);
            }

            if (!in_array('ROLE_ADMIN', $currentUser->getRoles())) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $userToDelete = $this->em->getRepository(User::class)->findOneBy(['email' => $email]);
            
            if (!$userToDelete) {
                return $this->jsonError('Utilisateur non trouvé', 404);
            }

            $currentUserEmail = $currentUser->getUserIdentifier();
            if ($currentUserEmail === $userToDelete->getEmail()) {
                return $this->jsonError('Vous ne pouvez pas supprimer votre propre compte', 400);
            }

            $this->em->remove($userToDelete);
            $this->em->flush();

            return $this->jsonSuccess(['message' => 'Utilisateur supprimé avec succès']);

        } catch (\Exception $e) {
            error_log('Delete user error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

   #[Route('/api/orders/{id}/status', name: 'api_update_order_status', methods: ['PUT', 'OPTIONS'])]
   public function updateOrderStatus(Request $request, int $id): JsonResponse
{
    if ($request->getMethod() === 'OPTIONS') {
        return $this->json([], 200, $this->getCorsHeaders());
    }

    try {
        $user = $this->getUser();
        if (!$user) {
            return $this->jsonError('Non authentifié', 401);
        }

        $userRoles = $user->getRoles();
        $allowedRoles = ['ROLE_CHEF', 'ROLE_SERVEUR', 'ROLE_ADMIN'];
        
        if (empty(array_intersect($userRoles, $allowedRoles))) {
            return $this->jsonError('Accès non autorisé', 403);
        }

        $data = $this->getRequestData($request);
        $status = $data['status'] ?? null;

        if (!$status) {
            return $this->jsonError('Statut requis', 400);
        }

        $allowedStatuses = ['pending', 'paid', 'preparing', 'ready', 'delivered', 'cancelled', 'completed'];
        
        if (!in_array($status, $allowedStatuses)) {
            return $this->jsonError('Statut invalide. Valeurs autorisées: ' . implode(', ', $allowedStatuses), 400);
        }

        $order = $this->em->getRepository(Order::class)->find($id);
        
        if (!$order) {
            return $this->jsonError('Commande non trouvée', 404);
        }
        
        $order->setStatus($status);
        $order->setUpdatedAt(new \DateTime());
        
        $this->em->flush();

        // Créer une notification pour le client
        $clientUser = $order->getUser();
        if ($clientUser) {
            $statusLabel = $this->translateStatus($status);
            $this->createNotification(
                $clientUser,
                'order_status_changed',
                'Changement de statut',
                "Votre commande #{$id} est maintenant: {$statusLabel}",
                $id
            );
        }

        // Si le statut est "completed" (terminée), créer une notification pour le chef
        if ($status === 'completed') {
            $chefRole = 'ROLE_CHEF';
            $chefs = $this->em->getRepository(User::class)->findByRole($chefRole);
            foreach ($chefs as $chef) {
                $this->createNotification(
                    $chef,
                    'order_delivered',
                    '✅ Commande livrée',
                    "La commande #{$id} a été livrée avec succès. Total: " . number_format($order->getTotal(), 2) . " DT",
                    $id
                );
            }
        }

        // Si le statut est "ready", créer une notification pour le serveur
        if ($status === 'ready') {
            $serverRole = 'ROLE_SERVEUR';
            $servers = $this->em->getRepository(User::class)->findByRole($serverRole);
            foreach ($servers as $server) {
                $this->createNotification(
                    $server,
                    'order_ready_for_delivery',
                    '🚀 Commande prête à livrer',
                    "La commande #{$id} est prête pour la livraison. Total: " . number_format($order->getTotal(), 2) . " DT",
                    $id
                );
            }
        }

        return $this->jsonSuccess([
            'message' => 'Statut de la commande mis à jour',
            'order_id' => $id,
            'status' => $status,
            'translated_status' => $this->translateStatus($status)
        ]);

    } catch (\Exception $e) {
        error_log('Update order status error: ' . $e->getMessage());
        return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
    }
}

    private function translateStatus(string $status): string
    {
        $statusMap = [
            'pending' => 'en attente',
            'paid' => 'payée',
            'preparing' => 'en préparation',
            'ready' => 'prête',
            'delivered' => 'livrée',
            'cancelled' => 'annulée',
            'completed' => 'terminée'
        ];
        
        return $statusMap[$status] ?? $status;
    }

    #[Route('/api/orders', name: 'api_create_order', methods: ['POST', 'OPTIONS'])]
    public function createOrder(Request $request, EntityManagerInterface $em): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $data = $this->getRequestData($request);
            
            if (!isset($data['items'])) {
                return $this->jsonError('Données invalides: items requis', 400);
            }

            $order = new Order();
            $order->setUser($user);
            $order->setStatus('pending');
            $order->setCreatedAt(new \DateTime());
            $order->setUpdatedAt(new \DateTime());

            foreach ($data['items'] as $itemData) {
                if (!isset($itemData['product_id']) || !isset($itemData['quantity'])) {
                    return $this->jsonError('Données d\'article invalides: product_id et quantity requis', 400);
                }

                $product = $em->getRepository(Product::class)->find($itemData['product_id']);
                if (!$product) {
                    return $this->jsonError('Produit non trouvé: ' . $itemData['product_id'], 404);
                }

                $orderItem = new OrderItem();
                $orderItem->setProduct($product);
                $orderItem->setQuantity($itemData['quantity']);
                $orderItem->setOrder($order);

                $em->persist($orderItem);
            }

            $em->persist($order);
            $em->flush();

            return $this->jsonSuccess([
                'id' => $order->getId(),
                'status' => $order->getStatus(),
                'message' => 'Commande créée avec succès'
            ], 201);

        } catch (\Exception $e) {
            error_log('Create order error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/order-notifications', name: 'api_order_notifications', methods: ['GET', 'OPTIONS'])]
    public function getOrderNotifications(Request $request): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return new JsonResponse([
                    'success' => false,
                    'error' => 'Non authentifié'
                ], 401, $this->getCorsHeaders());
            }

            // Récupérer les commandes prêtes à être livrées
            $orderRepository = $this->em->getRepository(Order::class);
            
            // Récupérer les commandes avec statut "prête" ou "ready" ou "completed" pour le serveur
            $readyOrders = $orderRepository->createQueryBuilder('o')
                ->where('o.status = :status1')
                ->setParameter('status1', 'ready')
                ->orWhere('o.status = :status2')
                ->setParameter('status2', 'prête')
                ->orWhere('o.status = :status3')
                ->setParameter('status3', 'completed')
                ->getQuery()
                ->getResult();

            $notifications = [];
            foreach ($readyOrders as $order) {
                $updatedAt = $order->getUpdatedAt() 
                    ? $order->getUpdatedAt()->format('Y-m-d H:i:s') 
                    : 'Date inconnue';
                
                $message = ($order->getStatus() === 'completed') 
                    ? 'Commande #' . $order->getId() . ' a été livrée avec succès'
                    : 'Commande #' . $order->getId() . ' est prête à être livrée';
                    
                $notifications[] = [
                    'id' => $order->getId(),
                    'message' => $message,
                    'order_id' => $order->getId(),
                    'created_at' => $updatedAt,
                    'read' => false
                ];
            }

            return new JsonResponse([
                'success' => true,
                'notifications' => $notifications
            ], 200, $this->getCorsHeaders());

        } catch (\Exception $e) {
            error_log('Get notifications error: ' . $e->getMessage());
            return new JsonResponse([
                'success' => false,
                'error' => 'Erreur serveur: ' . $e->getMessage()
            ], 500, $this->getCorsHeaders());
        }
    }

    #[Route('/api/real-orders', name: 'api_real_orders', methods: ['GET', 'OPTIONS'])]
    public function getRealOrders(Request $request): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $userRoles = $user->getRoles();
            $allowedRoles = ['ROLE_CHEF', 'ROLE_SERVEUR', 'ROLE_ADMIN'];
            
            if (empty(array_intersect($userRoles, $allowedRoles))) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $orders = $this->em->getRepository(Order::class)->findAll();
            $ordersData = [];

            foreach ($orders as $order) {
                $orderItems = [];
                if (method_exists($order, 'getOrderItems')) {
                    foreach ($order->getOrderItems() as $item) {
                        $orderItems[] = [
                            'name' => method_exists($item, 'getProduct') && $item->getProduct() ? $item->getProduct()->getName() : 'Produit inconnu',
                            'quantity' => method_exists($item, 'getQuantity') ? $item->getQuantity() : 1,
                            'price' => method_exists($item, 'getUnitPrice') ? $item->getUnitPrice() : 0
                        ];
                    }
                }

                $ordersData[] = [
                    'id' => $order->getId(),
                    'status' => $this->translateStatus($order->getStatus()),
                    'total' => method_exists($order, 'getTotal') ? $order->getTotal() : 0,
                    'user' => method_exists($order, 'getUser') && $order->getUser() ? $order->getUser()->getUserIdentifier() : 'Utilisateur inconnu',
                    'orderItems' => $orderItems,
                    'createdAt' => method_exists($order, 'getCreatedAt') && $order->getCreatedAt() ? $order->getCreatedAt()->format('Y-m-d H:i:s') : 'Date inconnue',
                    'updatedAt' => method_exists($order, 'getUpdatedAt') && $order->getUpdatedAt() ? $order->getUpdatedAt()->format('Y-m-d H:i:s') : null
                ];
            }

            return $this->jsonSuccess(['orders' => $ordersData]);

        } catch (\Exception $e) {
            error_log('Get real orders error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

  #[Route('/api/products-list', name: 'api_get_products', methods: ['GET', 'OPTIONS'])]
public function getProducts(Request $request): JsonResponse
{
    if ($request->getMethod() === 'OPTIONS') {
        return new JsonResponse([], 200, array_merge($this->getCorsHeaders(), [
            'Content-Type' => 'application/json'
        ]));
    }

    try {
        $productRepository = $this->em->getRepository(Product::class);
        $products = $productRepository->findAll();

        $productsData = [];
        foreach ($products as $product) {
            // Ensure all fields are properly cast to avoid type issues
            $productsData[] = [
                'id' => (int)$product->getId(),
                'name' => (string)$product->getName(),
                'price' => (float)$product->getPrice(),
                'category' => $product->getCategory() ?? 'Autre',
                'image' => $product->getImage() ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
                'rating' => (float)($product->getRating() ?? 4.0),
                'prepTime' => $product->getPrepTime() ?? '15-20 min',
                'isPopular' => (bool)($product->getPopulaire() ?? false),
            ];
        }

        return new JsonResponse([
            'success' => true,
            'data' => $productsData
        ], 200, array_merge($this->getCorsHeaders(), [
            'Content-Type' => 'application/json'
        ]));
    } catch (\Exception $e) {
        error_log('Get products error: ' . $e->getMessage());
        return new JsonResponse([
            'success' => false,
            'error' => 'Erreur serveur: ' . $e->getMessage()
        ], 500, $this->getCorsHeaders());
    }
}

#[Route('/api/notifications', name: 'api_get_notifications', methods: ['GET'])]
    public function getNotifications(Request $request): JsonResponse
    {
        try {
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $notificationRepo = $this->em->getRepository(Notification::class);
            
            // Récupérer uniquement les notifications de l'utilisateur connecté
            $notifications = $notificationRepo->findBy(
                ['user' => $user], 
                ['createdAt' => 'DESC'], 
                100
            );

            $data = [];
            foreach ($notifications as $notif) {
                $data[] = [
                    'id' => $notif->getId(),
                    'type' => $notif->getType(),
                    'title' => $notif->getTitle(),
                    'message' => $notif->getMessage(),
                    'orderId' => $notif->getOrderId(),
                    'isRead' => $notif->isRead(),
                    'createdAt' => $notif->getCreatedAt()->format('Y-m-d H:i:s'),
                ];
            }

            return $this->jsonSuccess($data);
        } catch (\Exception $e) {
            error_log('Get notifications error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/notifications/{id}', name: 'api_delete_notification', methods: ['DELETE'])]
    public function deleteNotification(int $id, Request $request): JsonResponse
    {
        try {
            /** @var \App\Entity\User $user */
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $notificationRepo = $this->em->getRepository(Notification::class);
            /** @var \App\Entity\Notification|null $notification */
            $notification = $notificationRepo->find($id);

            if (!$notification) {
                return $this->jsonError('Notification non trouvée', 404);
            }

            // Vérifier que l'utilisateur a le droit de supprimer cette notification
            /** @var \App\Entity\User $notificationUser */
            $notificationUser = $notification->getUser();
            if ($notificationUser && $notificationUser->getId() !== $user->getId()) {
                return $this->jsonError('Accès refusé', 403);
            }

            $this->em->remove($notification);
            $this->em->flush();

            return $this->jsonSuccess(['message' => 'Notification supprimée']);
        } catch (\Exception $e) {
            error_log('Delete notification error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/notifications/{id}/read', name: 'api_mark_notification_read', methods: ['PUT'])]
    public function markNotificationAsRead(int $id, Request $request): JsonResponse
    {
        try {
            /** @var \App\Entity\User $user */
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $notificationRepo = $this->em->getRepository(Notification::class);
            /** @var \App\Entity\Notification|null $notification */
            $notification = $notificationRepo->find($id);

            if (!$notification) {
                return $this->jsonError('Notification non trouvée', 404);
            }

            // Vérifier que l'utilisateur a le droit de modifier cette notification
            /** @var \App\Entity\User $notificationUser */
            $notificationUser = $notification->getUser();
            if ($notificationUser && $notificationUser->getId() !== $user->getId()) {
                return $this->jsonError('Accès refusé', 403);
            }

            $notification->setIsRead(true);
            $this->em->flush();

            return $this->jsonSuccess(['message' => 'Notification marquée comme lue']);
        } catch (\Exception $e) {
            error_log('Mark notification read error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    // Service helper to create notifications
    public function createNotification(User $user, string $type, string $title, string $message, ?int $orderId = null): void
    {
        try {
            $notification = new Notification();
            $notification->setUser($user);
            $notification->setType($type);
            $notification->setTitle($title);
            $notification->setMessage($message);
            if ($orderId) {
                $notification->setOrderId($orderId);
            }
            $notification->setIsRead(false);
            // createdAt is already set in the constructor

            $this->em->persist($notification);
            $this->em->flush();
        } catch (\Exception $e) {
            error_log('Create notification error: ' . $e->getMessage());
        }
    }

    // ===== HELPER METHODS =====

    private function getRequestData(Request $request): array
    {
        if (0 === strpos($request->headers->get('Content-Type'), 'application/json')) {
            $data = json_decode($request->getContent(), true);
            return is_array($data) ? $data : [];
        }
        return $request->request->all();
    }

    private function getCorsHeaders(): array
    {
        return [
            'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers' => 'Content-Type, Authorization, Accept, X-Requested-With, ngrok-skip-browser-warning',
            'Access-Control-Allow-Credentials' => 'true',
            'Access-Control-Max-Age' => '3600',
        ];
    }

    private function jsonSuccess($data, int $status = 200): JsonResponse
    {
        return new JsonResponse([
            'success' => true,
            'data' => $data
        ], $status, array_merge($this->getCorsHeaders(), [
            'Content-Type' => 'application/json'
        ]));
    }

    private function jsonError(string $message, int $status = 400): JsonResponse
    {
        return new JsonResponse([
            'success' => false,
            'error' => $message
        ], $status, $this->getCorsHeaders());
    }
}