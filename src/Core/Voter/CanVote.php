<?php

declare(strict_types=1);

namespace VPNMinute\Core\Voter;

interface CanVote
{
    /**
     * @param mixed $data
     *
     * @return string[]
     */
    public function vote($data): array;

    public function hasKnowledgeOn(string $subject): bool;
}
