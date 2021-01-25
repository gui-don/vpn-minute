<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\Assembly;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\Assembly\Assembly;
use VPNMinute\Core\Assembly\CanDeliberate;
use VPNMinute\Core\Exception\InternalConfigurationException;
use VPNMinute\Core\Voter\CanVote;

class AssemblySpec extends ObjectBehavior
{
    public const DATA = 'DATA';
    public const SUBJECT = 'TEST';
    public const VOTER1_RESULT = [1, 2, 3];
    public const VOTER2_RESULT = [2];
    public const VOTER3_RESULT = [];
    public const VOTER4_RESULT = [2, 5, 6, 7];

    public function let(CanVote $voter1, CanVote $voter2, CanVote $voter3, CanVote $voter4)
    {
        $voter1->hasKnowledgeOn(self::SUBJECT)->willReturn(true);
        $voter2->hasKnowledgeOn(self::SUBJECT)->willReturn(true);
        $voter3->hasKnowledgeOn(self::SUBJECT)->willReturn(true);
        $voter4->hasKnowledgeOn(self::SUBJECT)->willReturn(true);

        $voter1->vote(self::DATA)->willReturn(self::VOTER1_RESULT);
        $voter2->vote(self::DATA)->willReturn(self::VOTER2_RESULT);
        $voter3->vote(self::DATA)->willReturn(self::VOTER3_RESULT);
        $voter4->vote(self::DATA)->willReturn(self::VOTER4_RESULT);

        $this->setSubject(self::SUBJECT);
        $this->setMethod(Assembly::METHOD_CONSENSUS);
    }

    public function it_is_initializable()
    {
        $this->shouldHaveType(Assembly::class);
    }

    public function it_can_deliberate()
    {
        $this->shouldImplement(CanDeliberate::class);
    }

    public function it_gives_access_to_its_subject()
    {
        $this->getSubject()->shouldReturn(self::SUBJECT);
    }

    public function it_gives_access_to_its_method()
    {
        $this->getMethod()->shouldReturn(Assembly::METHOD_CONSENSUS);
    }

    public function it_can_store_and_return_voters($voter1, $voter2)
    {
        $this->addVoter($voter1);
        $this->addVoter($voter2);

        $this->getVoters()->shouldReturn([$voter1, $voter2]);
    }

    public function it_does_not_store_voters_that_does_not_have_knowledge_the_assembly_subject($voter1, $voter2)
    {
        $voter1->hasKnowledgeOn(self::SUBJECT)->willReturn(false);

        $this->addVoter($voter1);
        $this->addVoter($voter2);

        $this->getVoters()->shouldReturn([$voter2]);
    }

    public function it_throws_an_exception_when_trying_to_deliberate_without_a_valid_method()
    {
        $this->setMethod(10);

        $this->shouldThrow(InternalConfigurationException::class)->during('deliberate', [self::DATA]);
    }

    public function it_deliberates_with_consensus_method($voter1, $voter2, $voter3, $voter4)
    {
        $this->addVoter($voter1);
        $this->addVoter($voter2);
        $this->addVoter($voter3);
        $this->addVoter($voter4);

        $this->deliberate(self::DATA)->shouldReturn([2, 1, 3, 5, 6, 7]);
    }

    public function it_deliberates_with_majority_method($voter1, $voter2, $voter3, $voter4)
    {
        $this->setMethod(Assembly::METHOD_MAJORITY);

        $this->addVoter($voter1);
        $this->addVoter($voter2);
        $this->addVoter($voter3);
        $this->addVoter($voter4);

        $this->deliberate(self::DATA)->shouldReturn([2]);
    }

    public function it_deliberates_with_veto_method($voter1, $voter2, $voter3, $voter4)
    {
        $this->setMethod(Assembly::METHOD_VETO);

        $this->addVoter($voter1);
        $this->addVoter($voter2);
        $this->addVoter($voter3);
        $this->addVoter($voter4);

        $this->deliberate(self::DATA)->shouldReturn([]);
    }

    public function it_deliberates_with_no_results_without_voters()
    {
        $this->deliberate(self::DATA)->shouldReturn([]);

        $this->setMethod(Assembly::METHOD_MAJORITY);
        $this->deliberate(self::DATA)->shouldReturn([]);

        $this->setMethod(Assembly::METHOD_VETO);
        $this->deliberate(self::DATA)->shouldReturn([]);
    }

    public function it_calls_the_voters_on_each_deliberation($voter2)
    {
        $this->setMethod(Assembly::METHOD_VETO);

        $this->addVoter($voter2);

        $voter2->vote(self::DATA)->shouldBeCalled(3);

        $this->deliberate(self::DATA)->shouldReturn([2]);
        $this->deliberate(self::DATA)->shouldReturn([2]);
        $this->deliberate(self::DATA)->shouldReturn([2]);
    }
}
