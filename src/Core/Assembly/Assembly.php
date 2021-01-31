<?php

declare(strict_types=1);

namespace VPNMinute\Core\Assembly;

use Rico\Slib\ArrayUtils;
use VPNMinute\Core\Exception\InternalConfigurationException;
use VPNMinute\Core\Voter\CanVote;

/**
 *  lass to deliberate on a $subject using $method thanks to $voters.
 */
class Assembly implements CanDeliberate
{
    /**
     * @var CanVote[]
     */
    protected array $voters = [];
    protected int $method;
    protected string $subject;

    /**
     * @param mixed $data
     *
     * @throws InternalConfigurationException
     *
     * @return array[string]
     */
    final public function deliberate($data): array
    {
        if (CanDeliberate::METHOD_CONSENSUS === $this->method) {
            return $this->deliberateWithConsensus($data);
        } elseif (CanDeliberate::METHOD_MAJORITY === $this->method) {
            return $this->deliberateWithMajority($data);
        } elseif (CanDeliberate::METHOD_VETO === $this->method) {
            return $this->deliberateWithVeto($data);
        }

        throw new InternalConfigurationException(sprintf('Invalid %s method “%s”. Allowed: %s', __CLASS__, $this->method, implode(', ', [CanDeliberate::METHOD_CONSENSUS, CanDeliberate::METHOD_MAJORITY, CanDeliberate::METHOD_VETO])));
    }

    // Getters & Setters

    public function addVoter(CanVote $voter): void
    {
        if (!$voter->hasKnowledgeOn($this->subject)) {
            return;
        }

        $this->voters[] = $voter;
    }

    /**
     * @return CanVote[]
     */
    public function getVoters(): array
    {
        return $this->voters;
    }

    public function getMethod(): int
    {
        return $this->method;
    }

    public function getSubject(): string
    {
        return $this->subject;
    }

    public function setMethod(int $method): void
    {
        $this->method = $method;
    }

    public function setSubject(string $subject): void
    {
        $this->subject = $subject;
    }

    private function deliberateWithConsensus($data): array
    {
        return ArrayUtils::orderByOccurrence($this->aggregateVote($data));
    }

    private function deliberateWithMajority($data): array
    {
        $votes = array_count_values($this->aggregateVote($data));
        arsort($votes);

        $votes = array_filter($votes, function ($count) {
            return $count >= $this->getMajorityNumberOfVote();
        });

        return array_keys($votes);
    }

    private function deliberateWithVeto($data): array
    {
        $votes = null;

        foreach ($this->getVoters() as $voter) {
            if (null === $votes) {
                $votes = $voter->vote($data);
                continue;
            }

            $votes = array_intersect($votes, $voter->vote($data));
        }

        if (null === $votes) {
            return [];
        }

        return $votes;
    }

    private function aggregateVote($data): array
    {
        return ArrayUtils::flatten(array_map(function ($voter) use ($data) {
            return $voter->vote($data);
        }, $this->getVoters()));
    }

    private function getMajorityNumberOfVote(): int
    {
        return (int) ceil(1 + (\count($this->voters) / 2));
    }
}
