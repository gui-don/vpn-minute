<?php

declare(strict_types=1);

namespace VPNMinute\Core\Assembly;

interface CanDeliberate
{
    /**
     * Votes will be ordered: first element has most votes, last got least votes.
     */
    public const METHOD_CONSENSUS = 1;

    /**
     * Only votes chosen by 50% + 1 voters will be kept, then ordered by most votes.
     */
    public const METHOD_MAJORITY = 2;

    /**
     * Only votes chosen by all voters will be kept.
     */
    public const METHOD_VETO = 3;

    /**
     * @param mixed $data
     *
     * @return string[]
     */
    public function deliberate($data): array;
}
