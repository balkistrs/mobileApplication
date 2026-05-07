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
use Symfony\Component\Security\Core\Authentication\Token\Storage\TokenStorageInterface;
use App\Entity\Notification;
use App\Entity\Product;
use App\Entity\OrderItem;
use App\Entity\Payment; // AJOUTER CET IMPORT
use App\Repository\UserRepository;
use App\Repository\OrderRepository;
use App\Repository\ProductRepository;
use App\Repository\NotificationRepository;
use App\Service\MailService;

class ApiAuthController extends AbstractController
{
    private $jwtManager;
    private $em;
    private $tokenStorage;
    private $userRepository;
    private $orderRepository;
    private $productRepository;
    private $notificationRepository;

    public function __construct(
        JWTTokenManagerInterface $jwtManager, 
        EntityManagerInterface $em,
        TokenStorageInterface $tokenStorage,
        UserRepository $userRepository,
        OrderRepository $orderRepository,
        ProductRepository $productRepository,
        NotificationRepository $notificationRepository
    ) {
        $this->jwtManager = $jwtManager;
        $this->em = $em;
        $this->tokenStorage = $tokenStorage;
        $this->userRepository = $userRepository;
        $this->orderRepository = $orderRepository;
        $this->productRepository = $productRepository;
        $this->notificationRepository = $notificationRepository;
    }
// Dans ApiAuthController.php, ajoutez cette méthode après createOrder()
// Dans ApiAuthController.php, remplacez la méthode createOrderPayment par celle-ci

#[Route('/api/orderspayment', name: 'api_create_order_payment', methods: ['POST', 'OPTIONS'])]
public function createOrderPayment(Request $request): JsonResponse
{
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        return $this->json([], 200, $this->getCorsHeaders());
    }

    try {
        $user = $this->getUser();
        if (!$user instanceof \App\Entity\User) {
            return $this->jsonError('Non authentifié', 401);
        }

        $data = json_decode($request->getContent(), true);
        
        if (!isset($data['items']) || !is_array($data['items']) || empty($data['items'])) {
            return $this->jsonError('Données invalides: items requis', 400);
        }

        // Créer la commande
        $order = new \App\Entity\Order();
        $order->setUser($user);
        $order->setStatus('pending');
        $order->setCreatedAt(new \DateTime());
        $order->setUpdatedAt(new \DateTime());
        
        // Vérifier si la méthode setTableNumber existe dans Order
        if (isset($data['table_number']) && $data['table_number'] > 0 && method_exists($order, 'setTableNumber')) {
            $order->setTableNumber($data['table_number']);
        }

        $total = 0;

        foreach ($data['items'] as $index => $itemData) {
            if (!isset($itemData['product_id']) || !isset($itemData['quantity'])) {
                return $this->jsonError("Données d'article invalides", 400);
            }

            $productEntity = $this->productRepository->find($itemData['product_id']);
            
            if (!$productEntity instanceof \App\Entity\Product) {
                return $this->jsonError('Produit non trouvé: ' . $itemData['product_id'], 404);
            }

            $orderItem = new \App\Entity\OrderItem();
            $orderItem->setProduct($productEntity);
            $orderItem->setQuantity((int)$itemData['quantity']);
            $orderItem->setOrder($order);
            
            $itemPrice = $productEntity->getPrice() * (int)$itemData['quantity'];
            $total += $itemPrice;

            $this->em->persist($orderItem);
        }

        $order->setTotal($total);
        $this->em->persist($order);
        $this->em->flush();

        // Créer un enregistrement de paiement en attente
        $payment = new \App\Entity\Payment();
        $payment->setOrderId($order->getId());
        $payment->setClientId($user->getId());
        $payment->setMethod('pending');
        $payment->setIsPartial(false);
        $payment->setAmount($total);
        $payment->setStatus('pending');
        $payment->setCreatedAt(new \DateTimeImmutable());
        
        // Ajouter le numéro de table si présent
        if (isset($data['table_number']) && $data['table_number'] > 0) {
            $payment->setTableNumber($data['table_number']);
        }
        
        $this->em->persist($payment);
        $this->em->flush();

        return $this->jsonSuccess([
            'order_id' => $order->getId(),
            'total' => $total,
            'status' => 'pending',
            'message' => 'Commande créée avec succès'
        ], 201);
        
    } catch (\Exception $e) {
        error_log('❌ Create order payment error: ' . $e->getMessage());
        return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
    }
}
    // ===== AUTHENTIFICATION =====

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

            $existingUser = $this->userRepository->findOneBy(['email' => $email]);
            if ($existingUser) {
                return $this->jsonError('Un utilisateur avec cet email existe déjà', 409);
            }

            $user = new User();
            $user->setEmail($email);
            $user->setPassword($passwordHasher->hashPassword($user, $password));
            $user->setRoles([$role]);
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
                    'name' => $user->getName(),
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

            $user = $this->userRepository->findOneBy(['email' => $email]);

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
                    'name' => $user->getName(),
                    'roles' => $user->getRoles()
                ]
            ]);

        } catch (\Exception $e) {
            error_log('Login error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur', 500);
        }
    }

    #[Route('/api/auth/google', name: 'api_auth_google', methods: ['POST', 'OPTIONS'])]
    public function googleAuth(Request $request, UserPasswordHasherInterface $passwordHasher): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $data = $this->getRequestData($request);

            if (!isset($data['email']) || !isset($data['google_id'])) {
                return $this->jsonError('Email et Google ID requis', 400);
            }

            $email = $data['email'];
            $googleId = $data['google_id'];
            $name = $data['name'] ?? explode('@', $email)[0];
            $photoUrl = $data['photo_url'] ?? null;

            $user = $this->userRepository->findOneBy(['email' => $email]);

            if (!$user) {
                $user = new User();
                $user->setEmail($email);
                $user->setName($name);
                
                $randomPassword = bin2hex(random_bytes(8));
                $user->setPassword($passwordHasher->hashPassword($user, $randomPassword));
                $user->setRoles(['ROLE_CLIENT']);
                $user->setGoogleId($googleId);
                
                if ($photoUrl) {
                    $user->setPhotoUrl($photoUrl);
                }

                $this->em->persist($user);
                $this->em->flush();

                $this->createNotification(
                    $user,
                    'welcome',
                    'Bienvenue sur Smart Resto Pro',
                    'Votre compte a été créé avec succès via Google'
                );
            } else {
                if (!$user->getGoogleId()) {
                    $user->setGoogleId($googleId);
                }
                if ($photoUrl && !$user->getPhotoUrl()) {
                    $user->setPhotoUrl($photoUrl);
                }
                $this->em->flush();
            }

            $token = $this->jwtManager->create($user);

            return $this->jsonSuccess([
                'token' => $token,
                'user' => [
                    'id' => $user->getId(),
                    'email' => $user->getEmail(),
                    'name' => $user->getName(),
                    'roles' => $user->getRoles(),
                    'google_id' => $user->getGoogleId(),
                    'photo_url' => $user->getPhotoUrl(),
                ]
            ]);

        } catch (\Exception $e) {
            error_log('Google auth error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    // ===== GESTION DES UTILISATEURS (ADMIN) =====

    #[Route('/api/admin/users', name: 'api_admin_users', methods: ['GET', 'OPTIONS'])]
    public function getUsers(): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $currentUser = $this->getUser();
            if (!$currentUser || !in_array('ROLE_ADMIN', $currentUser->getRoles())) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $users = $this->userRepository->findAll();
            $usersData = [];

            foreach ($users as $userItem) {
                $user = $this->asUser($userItem);
                if (!$user) {
                    continue;
                }
                
                $usersData[] = [
                    'id' => $user->getId(),
                    'email' => $user->getEmail(),
                    'name' => $user->getName() ?? '',
                    'roles' => $user->getRoles(),
                    'vote' => $user->getVote(),
                    'google_id' => $user->getGoogleId(),
                    'photo_url' => $user->getPhotoUrl(),
                    'created_at' => $user->getCreatedAt()?->format('Y-m-d H:i:s')
                ];
            }

            return $this->jsonSuccess(['users' => $usersData]);
        } catch (\Exception $e) {
            error_log('Get users error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    // Dans ApiAuthController.php, assurez-vous que cette méthode existe
    #[Route('/api/users/{email}', name: 'api_update_user', methods: ['PUT', 'OPTIONS'])]
    public function updateUser(Request $request, string $email): JsonResponse
    {
        if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $currentUser = $this->getUser();
            if (!$currentUser instanceof User) {
                return $this->jsonError('Non authentifié', 401);
            }

            // Décoder l'email
            $decodedEmail = urldecode($email);
            
            // Chercher l'utilisateur à modifier
            $user = $this->userRepository->findOneBy(['email' => $decodedEmail]);
            if (!$user instanceof User) {
                return $this->jsonError('Utilisateur non trouvé', 404);
            }

            // Vérifier les permissions
            $isAdmin = in_array('ROLE_ADMIN', $currentUser->getRoles());
            if (!$isAdmin && $currentUser->getId() !== $user->getId()) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $data = json_decode($request->getContent(), true);

            if (isset($data['name'])) {
                $user->setName($data['name']);
            }

            if (isset($data['email'])) {
                $newEmail = trim($data['email']);
                if (!filter_var($newEmail, FILTER_VALIDATE_EMAIL)) {
                    return $this->jsonError('Email invalide', 400);
                }

                $existingUser = $this->userRepository->findOneBy(['email' => $newEmail]);
                if ($existingUser && $existingUser->getId() !== $user->getId()) {
                    return $this->jsonError('Cet email est déjà utilisé', 400);
                }
                $user->setEmail($newEmail);
            }

            $this->em->flush();

            return $this->jsonSuccess([
                'message' => 'Utilisateur modifié avec succès',
                'user' => [
                    'id' => $user->getId(),
                    'email' => $user->getEmail(),
                    'name' => $user->getName() ?? '',
                    'roles' => $user->getRoles()
                ]
            ]);

        } catch (\Exception $e) {
            error_log('❌ Update user error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/admin/users/{id}', name: 'api_admin_delete_user', methods: ['DELETE', 'OPTIONS'])]
    public function deleteUserById(int $id): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $currentUser = $this->getUser();
            if (!$currentUser || !in_array('ROLE_ADMIN', $currentUser->getRoles())) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $userToDeleteEntity = $this->userRepository->find($id);
            $userToDelete = $this->asUser($userToDeleteEntity);
            
            if (!$userToDelete) {
                return $this->jsonError('Utilisateur non trouvé', 404);
            }


            $this->em->remove($userToDelete);
            $this->em->flush();

            return $this->jsonSuccess(['message' => 'Utilisateur supprimé avec succès']);
        } catch (\Exception $e) {
            error_log('Delete user error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/admin/users/{id}', name: 'api_admin_update_user', methods: ['PUT', 'OPTIONS'])]
    public function updateUserById(int $id, Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $currentUser = $this->getUser();
            if (!$currentUser || !in_array('ROLE_ADMIN', $currentUser->getRoles())) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $userEntity = $this->userRepository->find($id);
            $user = $this->asUser($userEntity);
            
            if (!$user) {
                return $this->jsonError('Utilisateur non trouvé', 404);
            }

            $data = json_decode($request->getContent(), true);

            if (isset($data['name'])) {
                $user->setName($data['name']);
            }

            if (isset($data['email'])) {
                $newEmail = trim($data['email']);
                if (!filter_var($newEmail, FILTER_VALIDATE_EMAIL)) {
                    return $this->jsonError('Email invalide', 400);
                }

                $existingUserEntity = $this->userRepository->findOneBy(['email' => $newEmail]);
                $existingUser = $this->asUser($existingUserEntity);
                if ($existingUser && $existingUser->getId() !== $user->getId()) {
                    return $this->jsonError('Cet email est déjà utilisé', 400);
                }
                $user->setEmail($newEmail);
            }

            if (isset($data['role'])) {
                $allowedRoles = ['ROLE_CLIENT', 'ROLE_CHEF', 'ROLE_SERVEUR', 'ROLE_ADMIN'];
                if (in_array($data['role'], $allowedRoles)) {
                    $user->setRoles([$data['role']]);
                }
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

    // ===== GESTION DES COMMANDES =====

    #[Route('/api/orders', name: 'api_orders', methods: ['GET', 'OPTIONS'])]
    public function getOrders(Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
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

            $statusFilter = $request->query->get('status');
            
            if ($statusFilter) {
                $ordersEntities = $this->orderRepository->findBy(['status' => $statusFilter], ['createdAt' => 'DESC']);
            } else {
                $ordersEntities = $this->orderRepository->findBy([], ['createdAt' => 'DESC']);
            }

            $orders = [];
            foreach ($ordersEntities as $orderItem) {
                /** @var \App\Entity\Order $order */
                $order = $orderItem;
                if (!$order instanceof \App\Entity\Order) {
                    continue;
                }
                
                $items = [];
                foreach ($order->getOrderItems() as $itemEntry) {
                    /** @var \App\Entity\OrderItem $item */
                    $item = $itemEntry;
                    if (!$item instanceof \App\Entity\OrderItem) {
                        continue;
                    }
                    
                    $product = $item->getProduct();
                    $items[] = [
                        'name' => $product ? $product->getName() : 'Article',
                        'quantity' => $item->getQuantity(),
                        'price' => $product ? $product->getPrice() : 0
                    ];
                }

                $clientUser = $order->getUser();
                $clientEmail = null;
                if ($clientUser instanceof \App\Entity\User) {
                    /** @var \App\Entity\User $clientUser */
                    $clientUser = $clientUser;
                    $clientEmail = $clientUser->getEmail();
                }

                $orders[] = [
                    'id' => $order->getId(),
                    'client' => $clientEmail,
                    'items' => $items,
                    'status' => $order->getStatusText(),
                    'rawStatus' => $order->getStatus(),
                    'total' => $order->getTotal(),
                    'createdAt' => $order->getCreatedAt()?->format('Y-m-d H:i:s'),
                    'updatedAt' => $order->getUpdatedAt()?->format('Y-m-d H:i:s')
                ];
            }

            return $this->jsonSuccess(['orders' => $orders]);
        } catch (\Exception $e) {
            error_log('Get orders error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur', 500);
        }
    }

    #[Route('/api/orders/{id}/status', name: 'api_update_order_status', methods: ['PUT', 'OPTIONS'])]
    public function updateOrderStatus(Request $request, int $id): JsonResponse
    {
        if ($this->isOptionsRequest()) {
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

            $data = json_decode($request->getContent(), true);
            $status = $data['status'] ?? null;

            if (!$status) {
                return $this->jsonError('Statut requis', 400);
            }

            $allowedStatuses = ['pending', 'paid', 'preparing', 'ready', 'delivered', 'cancelled', 'completed'];
            
            if (!in_array($status, $allowedStatuses)) {
                return $this->jsonError('Statut invalide', 400);
            }

            $orderEntity = $this->orderRepository->find($id);
            /** @var \App\Entity\Order|null $order */
            $order = $orderEntity;
            
            if (!$order instanceof \App\Entity\Order) {
                return $this->jsonError('Commande non trouvée', 404);
            }
            
            $order->setStatus($status);
            $order->setUpdatedAt(new \DateTime());
            $this->em->flush();

            $clientUser = $order->getUser();
            if ($clientUser instanceof \App\Entity\User) {
                /** @var \App\Entity\User $clientUser */
                $clientUser = $clientUser;
                $statusLabel = $this->translateStatus($status);
                $this->createNotification(
                    $clientUser,
                    'order_status_changed',
                    'Changement de statut',
                    "Votre commande #{$id} est maintenant: {$statusLabel}",
                    $id
                );
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

    #[Route('/api/user/orders', name: 'api_user_orders', methods: ['GET', 'OPTIONS'])]
    public function getUserOrders(Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $ordersEntities = $this->orderRepository->findBy(['user' => $user], ['createdAt' => 'DESC']);
            
            $ordersData = [];
            foreach ($ordersEntities as $orderEntity) {
                $order = $this->asOrder($orderEntity);
                if (!$order) {
                    continue;
                }
                
                $orderItems = [];
                foreach ($order->getOrderItems() as $itemEntity) {
                    $item = $this->asOrderItem($itemEntity);
                    if (!$item) {
                        continue;
                    }
                    
                    $product = $item->getProduct();
                    $orderItems[] = [
                        'name' => $product ? $product->getName() : 'Produit inconnu',
                        'quantity' => $item->getQuantity(),
                        'price' => $product ? $product->getPrice() : 0
                    ];
                }

                $ordersData[] = [
                    'id' => $order->getId(),
                    'status' => $order->getStatus(),
                    'status_text' => $order->getStatusText(),
                    'total' => $order->getTotal(),
                    'orderItems' => $orderItems,
                    'createdAt' => $order->getCreatedAt()?->format('Y-m-d H:i:s') ?? 'Date inconnue',
                ];
            }

            return $this->jsonSuccess(['orders' => $ordersData]);
        } catch (\Exception $e) {
            error_log('Get user orders error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/orders', name: 'api_create_order', methods: ['POST', 'OPTIONS'])]
    public function createOrder(Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user instanceof \App\Entity\User) {
                return $this->jsonError('Non authentifié', 401);
            }

            $data = json_decode($request->getContent(), true);
            
            if (!isset($data['items']) || !is_array($data['items']) || empty($data['items'])) {
                return $this->jsonError('Données invalides: items requis et doivent être un tableau non vide', 400);
            }

            $order = new \App\Entity\Order();
            $order->setUser($user);
            $order->setStatus('pending');
            $order->setCreatedAt(new \DateTime());
            $order->setUpdatedAt(new \DateTime());

            $total = 0;

            foreach ($data['items'] as $index => $itemData) {
                if (!isset($itemData['product_id']) || !isset($itemData['quantity'])) {
                    return $this->jsonError("Données d'article invalides à l'index $index: product_id et quantity requis", 400);
                }

                if (!is_numeric($itemData['product_id']) || $itemData['product_id'] <= 0) {
                    return $this->jsonError("Product_id invalide à l'index $index", 400);
                }

                if (!is_numeric($itemData['quantity']) || $itemData['quantity'] <= 0) {
                    return $this->jsonError("Quantity invalide à l'index $index", 400);
                }

                /** @var \App\Entity\Product|null $productEntity */
                $productEntity = $this->productRepository->find($itemData['product_id']);
                
                if (!$productEntity instanceof \App\Entity\Product) {
                    return $this->jsonError('Produit non trouvé: ' . $itemData['product_id'], 404);
                }

                $orderItem = new \App\Entity\OrderItem();
                $orderItem->setProduct($productEntity);
                $orderItem->setQuantity((int)$itemData['quantity']);
                $orderItem->setOrder($order);
                
                $itemPrice = $productEntity->getPrice() * (int)$itemData['quantity'];
                $total += $itemPrice;

                $this->em->persist($orderItem);
            }

            $order->setTotal($total);
            $this->em->persist($order);
            $this->em->flush();

            /** @var \App\Entity\User[] $chefsEntities */
            $chefsEntities = $this->userRepository->findByRole('ROLE_CHEF');
            foreach ($chefsEntities as $chefEntity) {
                if ($chefEntity instanceof \App\Entity\User) {
                    $this->createNotification(
                        $chefEntity,
                        'new_order',
                        'Nouvelle commande',
                        "Nouvelle commande #{$order->getId()} de {$user->getEmail()}",
                        $order->getId()
                    );
                }
            }

            return $this->jsonSuccess([
                'order_id' => $order->getId(),
                'status' => $order->getStatus(),
                'total' => $total,
                'message' => 'Commande créée avec succès'
            ], 201);
            
        } catch (\Exception $e) {
            error_log('❌ Create order error: ' . $e->getMessage());
            error_log('❌ Stack trace: ' . $e->getTraceAsString());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    // ===== PAIEMENT =====

  // Dans ApiAuthController.php, mettez à jour la méthode initiateD17Payment

#[Route('/api/payment/d17/initiate', name: 'api_payment_d17_initiate', methods: ['POST', 'OPTIONS'])]
public function initiateD17Payment(Request $request): JsonResponse
{
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        return $this->json([], 200, $this->getCorsHeaders());
    }

    try {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return $this->jsonError('Non authentifié', 401);
        }

        $data = json_decode($request->getContent(), true);
        
        if (!isset($data['order_id']) || !isset($data['amount'])) {
            return $this->jsonError('Données de paiement incomplètes', 400);
        }

        // Vérifier que la commande existe
        $order = $this->orderRepository->find($data['order_id']);
        if (!$order instanceof Order) {
            return $this->jsonError('Commande non trouvée', 404);
        }

        // Vérifier que l'utilisateur est bien le propriétaire de la commande
        if ($order->getUser()->getId() !== $user->getId()) {
            return $this->jsonError('Vous n\'êtes pas autorisé à payer cette commande', 403);
        }

        // Simulation d'un paiement réussi (à remplacer par un vrai appel API D17)
        $transactionId = 'D17_' . time() . '_' . rand(1000, 9999);
        
        // Enregistrer le paiement
        $payment = new Payment();
        $payment->setOrderId($data['order_id']);
        $payment->setClientId($user->getId());
        $payment->setMethod('D17');
        $payment->setIsPartial(false);
        $payment->setAmount($data['amount']);
        $payment->setStatus('completed');
        $payment->setTransactionId($transactionId);
        $payment->setCreatedAt(new \DateTimeImmutable());
        $payment->setUpdatedAt(new \DateTimeImmutable());
        
        $this->em->persist($payment);

        // Mettre à jour le statut de la commande
        $order->setStatus('paid');
        $order->setUpdatedAt(new \DateTime());
        
        $this->em->flush();

        // Créer une notification pour l'utilisateur
        $this->createNotification(
            $user,
            'payment_success',
            'Paiement réussi',
            "Votre paiement de {$data['amount']} DT pour la commande #{$data['order_id']} a été effectué avec succès.",
            $data['order_id']
        );

        return $this->jsonSuccess([
            'success' => true,
            'transaction_id' => $transactionId,
            'message' => 'Paiement effectué avec succès'
        ]);

    } catch (\Exception $e) {
        error_log('❌ Payment error: ' . $e->getMessage());
        return $this->jsonError('Erreur de paiement: ' . $e->getMessage(), 500);
    }
}

    #[Route('/api/orders/{id}', name: 'api_get_order', methods: ['GET', 'OPTIONS'])]
    public function getOrder(int $id): JsonResponse
    {
        if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $order = $this->orderRepository->find($id);
            
            if (!$order instanceof Order) {
                return $this->jsonError('Commande non trouvée', 404);
            }

            return $this->jsonSuccess([
                'id' => $order->getId(),
                'status' => $order->getStatus(),
                'total' => $order->getTotal(),
                'created_at' => $order->getCreatedAt()?->format('Y-m-d H:i:s')
            ]);

        } catch (\Exception $e) {
            error_log('❌ Get order error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur', 500);
        }
    }

    // ===== GESTION DES PRODUITS =====

    #[Route('/api/products-list', name: 'api_get_products', methods: ['GET', 'OPTIONS'])]
    public function getProducts(Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return new JsonResponse([], 200, $this->getCorsHeaders());
        }

        try {
            $productsEntities = $this->productRepository->findAll();

            $productsData = [];
            foreach ($productsEntities as $productEntity) {
                $product = $this->asProduct($productEntity);
                if (!$product) {
                    continue;
                }
                
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
            ], 200, $this->getCorsHeaders());
        } catch (\Exception $e) {
            error_log('Get products error: ' . $e->getMessage());
            return new JsonResponse([
                'success' => false,
                'error' => 'Erreur serveur: ' . $e->getMessage()
            ], 500, $this->getCorsHeaders());
        }
    }

    // ===== GESTION DES NOTIFICATIONS =====

    #[Route('/api/notifications', name: 'api_get_notifications', methods: ['GET', 'OPTIONS'])]
    public function getNotifications(Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user) {
                return $this->jsonError('Non authentifié', 401);
            }

            $notificationsEntities = $this->notificationRepository->findBy(
                ['user' => $user], 
                ['createdAt' => 'DESC'], 
                100
            );

            $data = [];
            foreach ($notificationsEntities as $notifEntity) {
                $notif = $this->asNotification($notifEntity);
                if (!$notif) {
                    continue;
                }
                
                $data[] = [
                    'id' => $notif->getId(),
                    'type' => $notif->getType(),
                    'title' => $notif->getTitle(),
                    'message' => $notif->getMessage(),
                    'orderId' => $notif->getOrderId(),
                    'isRead' => $notif->isRead(),
                    'created_at' => $notif->getCreatedAt()->format('Y-m-d H:i:s'),
                ];
            }

            return $this->jsonSuccess($data);
        } catch (\Exception $e) {
            error_log('Get notifications error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/notifications/{id}', name: 'api_delete_notification', methods: ['DELETE', 'OPTIONS'])]
    public function deleteNotification(int $id, Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user instanceof \App\Entity\User) {
                return $this->jsonError('Non authentifié', 401);
            }

            /** @var \App\Entity\Notification|null $notificationEntity */
            $notificationEntity = $this->notificationRepository->find($id);
            
            if (!$notificationEntity instanceof \App\Entity\Notification) {
                return $this->jsonError('Notification non trouvée', 404);
            }

            /** @var \App\Entity\User|null $notificationUser */
            $notificationUser = $notificationEntity->getUser();
            
            if (!$notificationUser instanceof \App\Entity\User) {
                return $this->jsonError('Utilisateur associé à la notification non trouvé', 404);
            }

            if ($notificationUser->getId() !== $user->getId()) {
                return $this->jsonError('Accès refusé - vous n\'êtes pas le propriétaire de cette notification', 403);
            }

            $this->em->remove($notificationEntity);
            $this->em->flush();

            return $this->jsonSuccess(['message' => 'Notification supprimée avec succès']);
            
        } catch (\Exception $e) {
            error_log('❌ Delete notification error: ' . $e->getMessage());
            error_log('❌ Stack trace: ' . $e->getTraceAsString());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    #[Route('/api/notifications/{id}/read', name: 'api_mark_notification_read', methods: ['PUT', 'OPTIONS'])]
    public function markNotificationAsRead(int $id, Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user instanceof \App\Entity\User) {
                return $this->jsonError('Non authentifié', 401);
            }

            /** @var \App\Entity\Notification|null $notificationEntity */
            $notificationEntity = $this->notificationRepository->find($id);
            
            if (!$notificationEntity instanceof \App\Entity\Notification) {
                return $this->jsonError('Notification non trouvée', 404);
            }

            /** @var \App\Entity\User|null $notificationUser */
            $notificationUser = $notificationEntity->getUser();
            
            if (!$notificationUser instanceof \App\Entity\User) {
                return $this->jsonError('Utilisateur associé à la notification non trouvé', 404);
            }

            if ($notificationUser->getId() !== $user->getId()) {
                return $this->jsonError('Accès refusé - vous n\'êtes pas le propriétaire de cette notification', 403);
            }

            $notificationEntity->setIsRead(true);
            $this->em->flush();

            return $this->jsonSuccess(['message' => 'Notification marquée comme lue avec succès']);
            
        } catch (\Exception $e) {
            error_log('❌ Mark notification read error: ' . $e->getMessage());
            error_log('❌ Stack trace: ' . $e->getTraceAsString());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }

    // ===== DASHBOARD STATS =====

    #[Route('/api/admin/dashboard/stats', name: 'api_admin_dashboard_stats', methods: ['GET', 'OPTIONS'])]
    public function getDashboardStats(Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $user = $this->getUser();
            if (!$user || !in_array('ROLE_ADMIN', $user->getRoles())) {
                return $this->jsonError('Accès non autorisé', 403);
            }

            $days = $request->query->getInt('days', 30);
            $startDate = (new \DateTime())->modify("-$days days");
            
            // Récupérer les données avec des valeurs par défaut si vides
            $topProducts = $this->getTopProducts($startDate);
            $revenue = $this->getRevenue($startDate);
            $newUsers = $this->getNewUsersCount($startDate);
            $totalOrders = $this->getTotalOrders($startDate);
            $averageOrderValue = $totalOrders > 0 ? $revenue / $totalOrders : 0;

            // Si aucune donnée, retourner des données de démonstration pour le test
            if (empty($topProducts) && $revenue == 0) {
                return $this->jsonSuccess([
                    'period' => [
                        'days' => $days,
                        'start_date' => $startDate->format('Y-m-d'),
                        'end_date' => (new \DateTime())->format('Y-m-d')
                    ],
                    'top_products' => [
                        ['name' => 'Poulet Braisé', 'total_quantity' => 45, 'revenue_formatted' => '38250 DT'],
                        ['name' => 'Attiéké Poisson', 'total_quantity' => 38, 'revenue_formatted' => '28500 DT'],
                        ['name' => 'Thieboudienne', 'total_quantity' => 32, 'revenue_formatted' => '28800 DT'],
                        ['name' => 'Yassa Poulet', 'total_quantity' => 28, 'revenue_formatted' => '22960 DT'],
                        ['name' => 'Mafé', 'total_quantity' => 25, 'revenue_formatted' => '20000 DT'],
                    ],
                    'revenue' => [
                        'total' => 158000,
                        'formatted' => '158 000 DT',
                        'currency' => 'DT'
                    ],
                    'new_users' => 24,
                    'total_orders' => 168,
                    'average_order_value' => 940,
                    'orders_by_status' => [
                        'pending' => 12,
                        'paid' => 45,
                        'preparing' => 23,
                        'ready' => 18,
                        'completed' => 70
                    ],
                    'daily_stats' => []
                ]);
            }

            return $this->jsonSuccess([
                'period' => [
                    'days' => $days,
                    'start_date' => $startDate->format('Y-m-d'),
                    'end_date' => (new \DateTime())->format('Y-m-d')
                ],
                'top_products' => $topProducts,
                'revenue' => [
                    'total' => round($revenue, 2),
                    'formatted' => number_format($revenue, 0) . ' DT',
                    'currency' => 'DT'
                ],
                'new_users' => $newUsers,
                'total_orders' => $totalOrders,
                'average_order_value' => round($averageOrderValue, 2),
                'orders_by_status' => $this->getOrdersByStatus($startDate),
                'daily_stats' => $this->getDailyStats($startDate, $days)
            ]);
        } catch (\Exception $e) {
            error_log('Dashboard stats error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur: ' . $e->getMessage(), 500);
        }
    }
  
    // ===== TEST =====

    #[Route('/api/test', name: 'api_test', methods: ['GET', 'OPTIONS'])]
    public function test(Request $request): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return new JsonResponse([], 200, $this->getCorsHeaders());
        }

        return new JsonResponse([
            'success' => true,
            'message' => 'API is working!',
            'timestamp' => time()
        ], 200, $this->getCorsHeaders());
    }

    // ===== MOT DE PASSE OUBLIÉ =====

    #[Route('/api/forgot-password', name: 'api_forgot_password', methods: ['POST', 'OPTIONS'])]
    public function forgotPassword(Request $request, MailService $mailService): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $data = json_decode($request->getContent(), true);
            
            if (!isset($data['email'])) {
                return $this->jsonError('Email requis', 400);
            }

            $email = trim($data['email']);
            
            $userEntity = $this->userRepository->findOneBy(['email' => $email]);
            $user = $this->asUser($userEntity);
            
            if (!$user) {
                usleep(rand(100000, 300000));
                return $this->jsonSuccess(['message' => 'Si cet email existe, un lien de réinitialisation a été envoyé']);
            }

            $resetToken = bin2hex(random_bytes(32));
            $user->setResetToken($resetToken);
            $user->setResetTokenExpiresAt((new \DateTime())->modify('+1 hour'));
            
            $this->em->flush();

            $emailSent = $mailService->sendResetPasswordEmail($user->getEmail(), $resetToken);
            
            if ($emailSent) {
                error_log("✅ Email envoyé à: " . $user->getEmail());
            }

            return $this->jsonSuccess(['message' => 'Si cet email existe, un lien de réinitialisation a été envoyé']);
        } catch (\Exception $e) {
            error_log('❌ Forgot password error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur', 500);
        }
    }

    #[Route('/api/reset-password', name: 'api_reset_password', methods: ['POST', 'OPTIONS'])]
    public function resetPassword(Request $request, UserPasswordHasherInterface $passwordHasher): JsonResponse
    {
        if ($this->isOptionsRequest()) {
            return $this->json([], 200, $this->getCorsHeaders());
        }

        try {
            $data = json_decode($request->getContent(), true);
            
            if (!isset($data['token']) || !isset($data['password'])) {
                return $this->jsonError('Token et nouveau mot de passe requis', 400);
            }

            $token = $data['token'];
            $newPassword = $data['password'];

            if (strlen($newPassword) < 6) {
                return $this->jsonError('Le mot de passe doit contenir au moins 6 caractères', 400);
            }

            $userEntity = $this->userRepository->findOneBy(['resetToken' => $token]);
            $user = $this->asUser($userEntity);
            
            if (!$user) {
                return $this->jsonError('Token invalide', 400);
            }

            $now = new \DateTime();
            if ($user->getResetTokenExpiresAt() < $now) {
                return $this->jsonError('Token expiré', 400);
            }

            $user->setPassword($passwordHasher->hashPassword($user, $newPassword));
            $user->setResetToken(null);
            $user->setResetTokenExpiresAt(null);
            
            $this->em->flush();

            return $this->jsonSuccess(['message' => 'Mot de passe réinitialisé avec succès']);
        } catch (\Exception $e) {
            error_log('❌ Reset password error: ' . $e->getMessage());
            return $this->jsonError('Erreur serveur', 500);
        }
    }

    // ===== MÉTHODES PRIVÉES =====

    private function isOptionsRequest(): bool
    {
        return $_SERVER['REQUEST_METHOD'] === 'OPTIONS';
    }

    private function getTopProducts(\DateTime $startDate, int $limit = 10): array
    {
        $conn = $this->em->getConnection();
        
        $sql = "
            SELECT 
                p.id,
                p.name,
                p.category,
                p.price,
                COALESCE(SUM(oi.quantity), 0) as total_quantity,
                COUNT(DISTINCT o.id) as order_count,
                COALESCE(SUM(oi.quantity * p.price), 0) as total_revenue
            FROM product p
            LEFT JOIN order_item oi ON p.id = oi.product_id
            LEFT JOIN orders o ON oi.order_id = o.id AND o.created_at >= :start_date
            GROUP BY p.id, p.name, p.category, p.price
            ORDER BY total_quantity DESC
            LIMIT :limit
        ";
        
        $stmt = $conn->prepare($sql);
        $stmt->bindValue('start_date', $startDate->format('Y-m-d H:i:s'));
        $stmt->bindValue('limit', $limit, \PDO::PARAM_INT);
        $result = $stmt->executeQuery();
        
        $products = [];
        foreach ($result->fetchAllAssociative() as $row) {
            $products[] = [
                'id' => (int)$row['id'],
                'name' => $row['name'],
                'category' => $row['category'] ?? 'Autre',
                'price' => (float)$row['price'],
                'total_quantity' => (int)$row['total_quantity'],
                'order_count' => (int)$row['order_count'],
                'total_revenue' => (float)$row['total_revenue'],
                'revenue_formatted' => number_format($row['total_revenue'], 2) . ' DT'
            ];
        }
        
        return $products;
    }
private function getRevenue(\DateTime $startDate): float
{
    $conn = $this->em->getConnection();
    
    $sql = "
        SELECT COALESCE(SUM(amount), 0) as total
        FROM payment
        WHERE created_at >= :start_date
        AND is_partial = 0
    ";
    
    $stmt = $conn->prepare($sql);
    $stmt->bindValue('start_date', $startDate->format('Y-m-d H:i:s'));
    $result = $stmt->executeQuery();
    
    return (float)$result->fetchOne();
}
    private function getNewUsersCount(\DateTime $startDate): int
    {
        $conn = $this->em->getConnection();
        
        $sql = "
            SELECT COUNT(*) as count
            FROM users
            WHERE created_at >= :start_date
        ";
        
        $stmt = $conn->prepare($sql);
        $stmt->bindValue('start_date', $startDate->format('Y-m-d H:i:s'));
        $result = $stmt->executeQuery();
        
        return (int)$result->fetchOne();
    }
private function getTotalOrders(\DateTime $startDate): int
{
    $conn = $this->em->getConnection();
    
    $sql = "
        SELECT COUNT(*) as count
        FROM orders
        WHERE created_at >= :start_date
    ";
    
    $stmt = $conn->prepare($sql);
    $stmt->bindValue('start_date', $startDate->format('Y-m-d H:i:s'));
    $result = $stmt->executeQuery();
    
    return (int)$result->fetchOne();
}
    private function getOrdersByStatus(\DateTime $startDate): array
    {
        $conn = $this->em->getConnection();
        
        $sql = "
            SELECT status, COUNT(*) as count
            FROM orders
            WHERE created_at >= :start_date
            GROUP BY status
        ";
        
        $stmt = $conn->prepare($sql);
        $stmt->bindValue('start_date', $startDate->format('Y-m-d H:i:s'));
        $result = $stmt->executeQuery();
        
        $statuses = [];
        foreach ($result->fetchAllAssociative() as $row) {
            $statuses[$row['status']] = (int)$row['count'];
        }
        
        return $statuses;
    }

    private function getDailyStats(\DateTime $startDate, int $days): array
    {
        $conn = $this->em->getConnection();
        
        $sql = "
            SELECT 
                DATE(created_at) as date,
                COUNT(*) as order_count,
                COALESCE(SUM(total), 0) as revenue,
                COUNT(DISTINCT user_id) as unique_customers
            FROM orders
            WHERE created_at >= :start_date
            GROUP BY DATE(created_at)
            ORDER BY date ASC
        ";
        
        $stmt = $conn->prepare($sql);
        $stmt->bindValue('start_date', $startDate->format('Y-m-d H:i:s'));
        $result = $stmt->executeQuery();
        
        $stats = [];
        $dateMap = [];
        
        for ($i = 0; $i <= $days; $i++) {
            $date = (clone $startDate)->modify("+$i days")->format('Y-m-d');
            $dateMap[$date] = [
                'date' => $date,
                'order_count' => 0,
                'revenue' => 0,
                'unique_customers' => 0
            ];
        }
        
        foreach ($result->fetchAllAssociative() as $row) {
            if (isset($dateMap[$row['date']])) {
                $dateMap[$row['date']] = [
                    'date' => $row['date'],
                    'order_count' => (int)$row['order_count'],
                    'revenue' => (float)$row['revenue'],
                    'unique_customers' => (int)$row['unique_customers']
                ];
            }
        }
        
        return array_values($dateMap);
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

            $this->em->persist($notification);
            $this->em->flush();
        } catch (\Exception $e) {
            error_log('Create notification error: ' . $e->getMessage());
        }
    }

    private function getRequestData(Request $request): array
    {
        if (strpos($request->headers->get('Content-Type', ''), 'application/json') === 0) {
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

    // ===== MÉTHODES HELPER DE CASTING =====

    /**
     * Convertit un objet en User si possible
     */
    private function asUser($object): ?User
    {
        return $object instanceof User ? $object : null;
    }

    /**
     * Convertit un objet en Order si possible
     */
    private function asOrder($object): ?Order
    {
        return $object instanceof Order ? $object : null;
    }

    /**
     * Convertit un objet en OrderItem si possible
     */
    private function asOrderItem($object): ?OrderItem
    {
        return $object instanceof OrderItem ? $object : null;
    }

    /**
     * Convertit un objet en Product si possible
     */
    private function asProduct($object): ?Product
    {
        return $object instanceof Product ? $object : null;
    }

    /**
     * Convertit un objet en Notification si possible
     */
    private function asNotification($object): ?Notification
    {
        return $object instanceof Notification ? $object : null;
    }
}