<?php

namespace App\Controller;

use App\Service\PaymentService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/payment')]
class PaymentController extends AbstractController
{
    private PaymentService $paymentService;
    private SerializerInterface $serializer;
    private ValidatorInterface $validator;

    public function __construct(
        PaymentService $paymentService,
        SerializerInterface $serializer,
        ValidatorInterface $validator
    ) {
        $this->paymentService = $paymentService;
        $this->serializer = $serializer;
        $this->validator = $validator;
    }

    #[Route('/process', name: 'api_payment_process', methods: ['POST', 'OPTIONS'])]
    public function processPayment(Request $request): JsonResponse
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
            $content = $request->getContent();
            error_log('Payment request: ' . $content);
            
            $data = json_decode($content, true);

            if (json_last_error() !== JSON_ERROR_NONE) {
                return new JsonResponse([
                    'status' => 'error',
                    'message' => 'Invalid JSON: ' . json_last_error_msg()
                ], Response::HTTP_BAD_REQUEST, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            // Validation des champs requis
            $requiredFields = ['order_id', 'amount'];
            foreach ($requiredFields as $field) {
                if (!isset($data[$field]) || $data[$field] === '') {
                    return new JsonResponse([
                        'status' => 'error',
                        'message' => "Missing required field: $field",
                        'received_data' => $data
                    ], Response::HTTP_BAD_REQUEST, [
                        'Access-Control-Allow-Origin' => '*',
                    ]);
                }
            }

            error_log('Processing payment for order: ' . $data['order_id']);
            
            $result = $this->paymentService->processPayment($data);

            error_log('Payment successful: ' . print_r($result, true));
            
            return new JsonResponse([
                'status' => 'success',
                'message' => 'Payment processed successfully',
                'data' => $result
            ], Response::HTTP_CREATED, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\InvalidArgumentException $e) {
            error_log('Payment validation error: ' . $e->getMessage());
            return new JsonResponse([
                'status' => 'error',
                'message' => $e->getMessage()
            ], Response::HTTP_BAD_REQUEST, [
                'Access-Control-Allow-Origin' => '*',
            ]);
            
        } catch (\Exception $e) {
            error_log('Payment error: ' . $e->getMessage());
            error_log('Stack trace: ' . $e->getTraceAsString());
            
            return new JsonResponse([
                'status' => 'error',
                'message' => 'Failed to process payment: ' . $e->getMessage()
            ], Response::HTTP_INTERNAL_SERVER_ERROR, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    #[Route('/status/{orderId}', name: 'api_payment_status', methods: ['GET', 'OPTIONS'])]
    public function getPaymentStatus(int $orderId, Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'GET, OPTIONS',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization',
            ]);
        }

        try {
            $status = $this->paymentService->getOrderStatus($orderId);

            if (!$status) {
                return new JsonResponse([
                    'status' => 'error',
                    'message' => 'Order not found'
                ], Response::HTTP_NOT_FOUND, [
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            return new JsonResponse([
                'status' => 'success',
                'order_id' => $orderId,
                'payment_status' => $status
            ], Response::HTTP_OK, [
                'Access-Control-Allow-Origin' => '*',
            ]);

        } catch (\Exception $e) {
            return new JsonResponse([
                'status' => 'error',
                'message' => 'Failed to get payment status: ' . $e->getMessage()
            ], Response::HTTP_INTERNAL_SERVER_ERROR, [
                'Access-Control-Allow-Origin' => '*',
            ]);
        }
    }

    #[Route('/test', name: 'api_payment_test', methods: ['GET', 'OPTIONS'])]
    public function testPayment(Request $request): JsonResponse
    {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            return new JsonResponse([], 200, [
                'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'GET, OPTIONS',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization',
            ]);
        }

        return new JsonResponse([
            'status' => 'success',
            'message' => 'Payment endpoint is working!',
            'timestamp' => time()
        ], Response::HTTP_OK, [
            'Access-Control-Allow-Origin' => '*',
        ]);
    }
}