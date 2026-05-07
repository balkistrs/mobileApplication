<?php

namespace App\Command;

use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use App\Entity\User;

#[AsCommand(
    name: 'app:fix-user-roles',
    description: 'Fix user roles format in database'
)]
class FixUserRolesCommand extends Command
{
    private $entityManager;

    public function __construct(EntityManagerInterface $entityManager)
    {
        $this->entityManager = $entityManager;
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->setDescription('Fix user roles format in database');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $users = $this->entityManager->getRepository(User::class)->findAll();
        
        foreach ($users as $user) {
            $roles = $user->getRoles();
            $newRoles = [];
            
            foreach ($roles as $role) {
                if (is_string($role) && preg_match('/\[.*\]/', $role)) {
                    // Décoder les rôles JSON
                    $decoded = json_decode($role, true);
                    if (is_array($decoded)) {
                        $newRoles = array_merge($newRoles, $decoded);
                    }
                } else {
                    $newRoles[] = $role;
                }
            }
            
            $user->setRoles(array_values(array_unique($newRoles)));
            $output->writeln("Fixed roles for user: " . $user->getEmail());
        }
        
        $this->entityManager->flush();
        $output->writeln("All user roles have been fixed!");

        return Command::SUCCESS;
    }
}