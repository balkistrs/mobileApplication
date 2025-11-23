<?php

namespace App\Security;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\AuthenticationException;
use Symfony\Component\Security\Core\Exception\CustomUserMessageAuthenticationException;
use Symfony\Component\Security\Http\Authenticator\AbstractAuthenticator;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Passport;
use Symfony\Component\Security\Http\Authenticator\Passport\SelfValidatingPassport;

class TokenAuthenticator extends AbstractAuthenticator
{
    private $entityManager;

    public function __construct(EntityManagerInterface $entityManager)
    {
        $this->entityManager = $entityManager;
    }

    public function supports(Request $request): ?bool
    {
        return $request->headers->has('Authorization');
    }

    public function authenticate(Request $request): Passport
    {
        $authorizationHeader = $request->headers->get('Authorization');
        
        if (null === $authorizationHeader || !str_starts_with($authorizationHeader, 'Bearer ')) {
            throw new CustomUserMessageAuthenticationException('No API token provided');
        }

        $token = substr($authorizationHeader, 7);

        try {
            $tokenData = json_decode(base64_decode($token), true);
            
            if (!$tokenData || !isset($tokenData['email']) || !isset($tokenData['exp']) || $tokenData['exp'] < time()) {
                throw new CustomUserMessageAuthenticationException('Invalid or expired token');
            }

            $user = $this->entityManager->getRepository(User::class)->findOneBy(['email' => $tokenData['email']]);
            
            if (!$user) {
                throw new CustomUserMessageAuthenticationException('User not found');
            }

            return new SelfValidatingPassport(new UserBadge($user->getEmail()));

        } catch (\Exception $e) {
            throw new CustomUserMessageAuthenticationException('Invalid token format');
        }
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response
    {
        return null;
    }

    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response
    {
        $data = [
            'error' => 'Authentication failed',
            'message' => strtr($exception->getMessageKey(), $exception->getMessageData())
        ];

        return new JsonResponse($data, Response::HTTP_UNAUTHORIZED);
    }
}